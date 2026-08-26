"""
Webhook router — receives Stream Chat events and dispatches to the agent.

Stream sends webhooks for: message.new, message.updated, etc.
We filter for @agent mentions and route to the agent service.
"""

import hashlib
import hmac
import logging

from fastapi import APIRouter, Header, HTTPException, Request

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
                    await send_poll_card(
                        channel_id=msg.cid,
                        poll_id=f"poll-{msg.message_id}",
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
                await send_agent_card(
                    channel_id=msg.cid,
                    summary="Sorry, I had trouble processing that. Could you try again?",
                    description=str(e)[:200],
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
