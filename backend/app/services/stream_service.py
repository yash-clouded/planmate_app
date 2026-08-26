"""
Stream Chat service — handles sending messages, creating bot users,
and managing channels through the Stream Chat API.
"""

import logging
from datetime import datetime, timezone

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

STREAM_BASE = settings.stream_api_base_url


def _channel_id(channel_id: str) -> str:
    """Strip the messaging: prefix if present, because the REST path already includes /channels/messaging/."""
    if channel_id.startswith("messaging:"):
        return channel_id[len("messaging:"):]
    return channel_id


async def _headers() -> dict:
    return {
        "Authorization": f"Bearer {settings.stream_api_key}",
        "Content-Type": "application/json",
    }


async def send_agent_message(
    channel_id: str,
    text: str,
    extra_data: dict | None = None,
) -> dict:
    """Send a message as the agent into a channel."""
    payload: dict = {
        "message": {
            "text": text,
            "user_id": "planmate-agent",
            "type": "regular",
        }
    }
    if extra_data:
        payload["message"]["attachments"] = [
            {
                "type": "custom",
                "custom": extra_data,
            }
        ]

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            f"{STREAM_BASE}/channels/messaging/{_channel_id(channel_id)}/message",
            headers=await _headers(),
            json=payload,
        )
        resp.raise_for_status()
        return resp.json()


async def send_agent_card(
    channel_id: str,
    summary: str,
    description: str = "",
    options: list[dict] | None = None,
    confirm_text: str = "",
    image_options: list[dict] | None = None,
) -> dict:
    """Send a rich agent response card to the channel."""
    card_data = {
        "card_type": "agent_response",
        "summary": summary,
        "description": description,
        "options": options or [],
        "image_options": image_options or [],
        "confirm_text": confirm_text,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    text = f"**PlanMate Agent**\n\n{summary}"
    if description:
        text += f"\n{description}"

    return await send_agent_message(channel_id, text, extra_data=card_data)


async def send_poll_card(
    channel_id: str,
    poll_id: str,
    question: str,
    options: list[str],
    duration_minutes: int = 60,
) -> dict:
    """Send a poll card to the channel."""
    card_data = {
        "card_type": "poll",
        "poll_id": poll_id,
        "question": question,
        "options": options,
        "duration_minutes": duration_minutes,
        "total_votes": 0,
    }

    text = f"**PlanMate Agent** — Poll\n\n{question}"
    return await send_agent_message(channel_id, text, extra_data=card_data)


async def send_poll_result(
    channel_id: str,
    question: str,
    winning_option: str,
) -> dict:
    """Send the final poll result to the channel."""
    text = f"**PlanMate Agent**\n\n✅ Group decided: **{winning_option}**"
    return await send_agent_message(channel_id, text)


async def send_sos_alert(
    channel_id: str,
    user_name: str,
    latitude: float,
    longitude: float,
) -> dict:
    """Send an SOS alert card to the trip group."""
    card_data = {
        "card_type": "sos",
        "user_name": user_name,
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    text = f"🚨 **SOS ALERT** — {user_name} has activated emergency SOS\nLocation: {latitude}, {longitude}"
    return await send_agent_message(channel_id, text, extra_data=card_data)


async def create_bot_user() -> dict:
    """Ensure the planmate-agent bot user exists in Stream."""
    if not settings.stream_api_key or not settings.stream_api_secret:
        return {"status": "skipped", "detail": "Stream API credentials not configured"}
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{STREAM_BASE}/users",
                headers=await _headers(),
                json={
                    "id": "planmate-agent",
                    "name": "PlanMate Agent",
                    "role": "user",
                    "image": "",
                },
            )
            if resp.status_code in (200, 201, 409):
                return {"status": "ok"}
            if resp.status_code == 404:
                return {"status": "error", "detail": f"Stream API endpoint not found (404). Check STREAM_API_BASE_URL. Response: {resp.text[:200]}"}
            return {"status": "error", "detail": f"HTTP {resp.status_code}: {resp.text[:200]}"}
    except Exception as e:
        return {"status": "error", "detail": str(e)[:200]}


async def add_agent_to_channel(channel_id: str) -> dict:
    """Add the agent as a member of a group channel."""
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(
            f"{STREAM_BASE}/channels/messaging/{_channel_id(channel_id)}",
            headers=await _headers(),
            json={
                "add_members": ["planmate-agent"],
            },
        )
        if resp.status_code in (200, 201, 409):
            return {"status": "ok"}
        return {"status": "error", "detail": resp.text}
