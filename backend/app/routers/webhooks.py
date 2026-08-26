"""
Webhook router — receives Stream Chat events and dispatches to the agent.

Stream sends webhooks for: message.new, message.updated, etc.
We filter for @agent mentions and route to the agent service.
"""

import hashlib
import hmac
import json
import logging

from datetime import datetime
from pathlib import Path

import httpx
from fastapi import APIRouter, File, Header, HTTPException, Request, UploadFile

from app.config import settings
from app.models.schemas import WebhookPayload
from app.services import redis_store
from app.services.agent import process_mention
from app.services.stream_service import (
    send_agent_card,
    send_poll_card,
    send_sos_alert as stream_send_sos_alert,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/webhooks", tags=["webhooks"])


def _verify_signature(payload: bytes, signature: str) -> bool:
    """Verify Stream webhook signature."""
    if not settings.webhook_secret:
        return True  # Skip verification if no secret configured
    expected = hmac.new(
        settings.webhook_secret.encode(),
        payload,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


@router.post("/stream")
async def stream_webhook(
    request: Request,
    x_stream_signature: str = Header(default=""),
):
    """
    Handle Stream Chat webhook events.

    Primary flow:
    1. Receive message.new event
    2. Store message in Redis
    3. If @agent is mentioned, process with AI
    4. Send agent response back to channel
    """
    body = await request.body()

    # Verify signature
    if settings.webhook_secret and not _verify_signature(body, x_stream_signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    try:
        payload = WebhookPayload.model_validate_json(body)
    except Exception as e:
        logger.warning(f"Invalid webhook payload: {e}")
        raise HTTPException(status_code=400, detail="Invalid payload")

    # Handle different event types
    if payload.event == "message.new" and payload.message:
        msg = payload.message

        # 1. Store message in rolling window
        await redis_store.store_message(
            channel_id=msg.cid,
            message={
                "user_id": msg.user_id,
                "text": msg.text,
                "message_id": msg.message_id,
                "created_at": msg.created_at,
            },
        )

        # 2. Check for @agent mention
        if "@agent" in msg.text.lower() or "@planmate" in msg.text.lower():
            logger.info(f"@agent mentioned in {msg.cid}: {msg.text[:80]}...")

            try:
                result = await process_mention(
                    channel_id=msg.cid,
                    mention_text=msg.text,
                )

                action_type = result.get("action_type", "info_only")

                # If it's a poll command, send poll card
                if action_type == "poll" and result.get("tool_calls"):
                    poll_call = result["tool_calls"][0]
                    params = poll_call.get("params", {})
                    poll_id = result.get("poll_id") or f"poll-{msg.message_id}"
                    try:
                        await redis_store.store_poll(
                            channel_id=msg.cid,
                            poll_id=poll_id,
                            question=params.get("question", "Group poll"),
                            options=params.get("options", ["Yes", "No"]),
                            duration_minutes=params.get("duration_minutes", 60),
                        )
                    except Exception:
                        pass
                    await send_poll_card(
                        channel_id=msg.cid,
                        poll_id=poll_id,
                        question=params.get("question", "Group poll"),
                        options=params.get("options", ["Yes", "No"]),
                        duration_minutes=params.get("duration_minutes", 60),
                    )
                else:
                    # Format the agent response
                    summary = result.get("summary", "")
                    description = result.get("description", "")
                    confirm_text = ""

                    if result.get("needs_confirmation") or action_type == "booking_search":
                        for tr in result.get("tool_results", []):
                            if tr["tool"] in ("search_hotels", "search_movies", "search_restaurants"):
                                results = tr["result"].get("results", [])
                                if results:
                                    price = results[0].get("price", 0)
                                    if price:
                                        confirm_text = f"Confirm & Pay ₹{price:,}"
                                    break

                    await send_agent_card(
                        channel_id=msg.cid,
                        summary=summary,
                        description=description,
                        confirm_text=confirm_text,
                    )

            except Exception as e:
                logger.exception(f"Agent processing failed for {msg.cid}")
                error_detail = str(e)
                await send_agent_card(
                    channel_id=msg.cid,
                    summary="Sorry, I had trouble processing that.",
                    description=error_detail[:400],
                )

    return {"status": "ok"}


@router.post("/poll/vote")
async def poll_vote(request: Request):
    """
    Cast a vote in a poll.
    """
    body = await request.json()
    channel_id = body.get("channel_id")
    poll_id = body.get("poll_id")
    user_id = body.get("user_id", "anonymous")
    option_index = body.get("option_index")

    if not channel_id or not poll_id or option_index is None:
        raise HTTPException(status_code=400, detail="channel_id, poll_id, and option_index required")

    try:
        result = await redis_store.cast_vote(channel_id, poll_id, user_id, option_index)
        return {"status": "ok", "votes": result}
    except Exception as e:
        logger.error(f"Poll vote failed: {e}")
        raise HTTPException(status_code=500, detail="Vote failed")


@router.post("/sos")
async def sos_alert(request: Request):
    """
    Broadcast an SOS alert to a group channel.
    """
    body = await request.json()
    channel_id = body.get("channel_id")
    user_name = body.get("user_name", "Unknown")
    latitude = body.get("latitude")
    longitude = body.get("longitude")

    if not channel_id or latitude is None or longitude is None:
        raise HTTPException(status_code=400, detail="channel_id, latitude, and longitude required")

    try:
        await stream_send_sos_alert(
            channel_id=channel_id,
            user_name=user_name,
            latitude=float(latitude),
            longitude=float(longitude),
        )
        return {"status": "ok", "message": "SOS alert sent"}
    except Exception as e:
        logger.error(f"SOS alert failed: {e}")
        raise HTTPException(status_code=500, detail="SOS alert failed")


@router.post("/confirm/{channel_id}")
async def confirm_booking_endpoint(channel_id: str):
    """
    Confirm a pending booking for a group.
    Called when the group taps 'Confirm & Pay' in the chat.
    """
    from app.services.agent import confirm_booking
    result = await confirm_booking(channel_id)
    return result


@router.get("/agent/health")
async def agent_health():
    """
    Diagnostics for the AI agent connection.
    Returns config status and tests the NVIDIA API with a minimal request.
    """
    from app.config import settings
    from app.services.agent import _call_ai

    status = {
        "nvidia_base_url": settings.nvidia_base_url,
        "nvidia_model": settings.nvidia_model,
        "nvidia_api_key_set": bool(settings.nvidia_api_key),
        "api_key_prefix": settings.nvidia_api_key[:8] + "..." if settings.nvidia_api_key else None,
    }

    try:
        test_result = await _call_ai("hi")
        status["test_call"] = {
            "ok": True,
            "summary": test_result.get("summary", "")[:120],
            "action_type": test_result.get("action_type", ""),
            "error": test_result.get("error"),
            "error_type": test_result.get("error_type"),
        }
    except Exception as e:
        status["test_call"] = {
            "ok": False,
            "error": str(e)[:300],
            "error_type": type(e).__name__,
        }

    return status


@router.post("/agent/command")
async def agent_command(request: Request):
    """
    Direct agent command endpoint for frontend.
    Handles poll, summarize, restaurants, and general chat commands.
    """
    body = await request.json()
    channel_id = body.get("channel_id")
    command = body.get("command", "chat")
    text = body.get("text", "")

    if not channel_id:
        raise HTTPException(status_code=400, detail="channel_id required")

    try:
        from app.services.agent import process_mention
        result = await process_mention(
            channel_id=channel_id,
            mention_text=text,
        )
        return result
    except Exception as e:
        logger.exception(f"Agent command failed for {channel_id}")
        raise HTTPException(status_code=500, detail=str(e)[:200])


@router.get("/polls/{channel_id}")
async def get_polls(channel_id: str):
    """
    Get all active polls for a channel.
    """
    try:
        polls = await redis_store.get_polls(channel_id)
        return {"polls": polls}
    except Exception as e:
        logger.error(f"Failed to fetch polls: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch polls")


@router.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    """
    Upload an image for group photos, avatars, etc.
    Returns the public URL of the uploaded image.
    """
    try:
        upload_dir = Path("uploads")
        upload_dir.mkdir(exist_ok=True)

        file_ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
        file_name = f"{datetime.utcnow().timestamp()}.{file_ext}"
        file_path = upload_dir / file_name

        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)

        # In production, serve these via CDN or cloud storage (S3, Cloudinary, etc.)
        # Return relative path; frontend constructs full URL from backendUrl
        return {
            "url": f"/uploads/{file_name}",
            "filename": file_name,
            "size": len(content),
        }
    except Exception as e:
        logger.error(f"Image upload failed: {e}")
        raise HTTPException(status_code=500, detail="Image upload failed")


@router.post("/itinerary/generate")
async def generate_itinerary(request: Request):
    """
    Generate a trip itinerary based on group conversation context.
    """
    body = await request.json()
    channel_id = body.get("channel_id")
    days = body.get("days", 3)

    if not channel_id:
        raise HTTPException(status_code=400, detail="channel_id required")

    try:
        recent = await redis_store.get_recent_messages(channel_id, limit=50)
        context_str = "\n".join(
            f"[{m.get('user_name', m.get('user_id', '?'))}]: {m['text']}"
            for m in recent
        )

        itinerary_prompt = f"""Generate a {days}-day trip itinerary based on this conversation:

{context_str}

Format as JSON:
{{
  "title": "Trip Title",
  "days": [
    {{
      "day": 1,
      "theme": "Day 1 theme",
      "activities": [
        {{"time": "9:00 AM", "activity": "Activity description", "location": "Place name"}}
      ]
    }}
  ]
}}"""

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                f"{settings.nvidia_base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.nvidia_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.nvidia_model,
                    "messages": [
                        {"role": "system", "content": "You are a trip planner. Generate detailed itineraries in JSON format only."},
                        {"role": "user", "content": itinerary_prompt},
                    ],
                    "temperature": 0.5,
                    "max_tokens": 2048,
                },
            )
            response.raise_for_status()
            data = response.json()

        content = data["choices"][0]["message"].get("content", "")
        try:
            if "```json" in content:
                json_str = content.split("```json")[1].split("```")[0].strip()
            else:
                start = content.find("{")
                end = content.rfind("}") + 1
                json_str = content[start:end] if start >= 0 else content
            itinerary = json.loads(json_str)
        except Exception:
            itinerary = {
                "title": "Trip Plan",
                "days": [
                    {
                        "day": i + 1,
                        "theme": f"Day {i + 1}",
                        "activities": [{"time": "TBD", "activity": "Plan activities", "location": "TBD"}],
                    }
                    for i in range(days)
                ],
            }

        return itinerary
    except Exception as e:
        logger.error(f"Itinerary generation failed: {e}")
        raise HTTPException(status_code=500, detail="Itinerary generation failed")
