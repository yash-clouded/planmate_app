"""
Stream Chat service — handles sending messages, creating bot users,
and managing channels through the official Stream Chat server SDK.

The server SDK signs a JWT with the API secret for every request, which is
what Stream's server-side REST API requires. (Sending the raw API key as a
Bearer token — as an earlier version did — always returns 401.)
"""

import logging
from datetime import datetime, timezone

from stream_chat import StreamChatAsync

from app.config import settings

logger = logging.getLogger(__name__)

# Bot user that posts agent responses, polls, and SOS cards into channels.
AGENT_USER_ID = "planmate-agent"
AGENT_USER_NAME = "PlanMate Agent"


def _strip_prefix(channel_id: str) -> str:
    """Return the bare channel id, dropping any leading 'messaging:' prefix."""
    if channel_id.startswith("messaging:"):
        return channel_id[len("messaging:"):]
    return channel_id


def _client() -> StreamChatAsync:
    """Build an async Stream server client. Use as an async context manager."""
    return StreamChatAsync(
        api_key=settings.stream_api_key,
        api_secret=settings.stream_api_secret,
    )


def _credentials_ok() -> bool:
    return bool(settings.stream_api_key and settings.stream_api_secret)


async def issue_user_token(user_id: str, name: str) -> str:
    """Upsert the Stream user and mint a connection token (JWT) for the client.

    `create_token` is pure local JWT signing (no network), but `upsert_user`
    is a real call, so we run both inside the client's lifecycle and let the
    context manager close the underlying session.
    """
    async with _client() as chat:
        await chat.upsert_user({"id": user_id, "name": name})
        return chat.create_token(user_id)


async def upsert_user(user_id: str, name: str) -> None:
    """Ensure a Stream user exists / is up to date."""
    async with _client() as chat:
        await chat.upsert_user({"id": user_id, "name": name})


async def send_agent_message(
    channel_id: str,
    text: str,
    extra_data: dict | None = None,
) -> dict:
    """Send a message as the agent into a channel."""
    message: dict = {"text": text}
    if extra_data:
        # Custom fields ride along on the message so the client can render a card.
        message["planmate_card"] = extra_data

    async with _client() as chat:
        channel = chat.channel("messaging", _strip_prefix(channel_id))
        return await channel.send_message(message, AGENT_USER_ID)


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

    text = (
        f"🚨 **SOS ALERT** — {user_name} has activated emergency SOS\n"
        f"Location: {latitude}, {longitude}"
    )
    return await send_agent_message(channel_id, text, extra_data=card_data)


async def create_bot_user() -> dict:
    """Ensure the planmate-agent bot user exists in Stream."""
    if not _credentials_ok():
        return {"status": "skipped", "detail": "Stream API credentials not configured"}

    try:
        async with _client() as chat:
            await chat.upsert_user(
                {
                    "id": AGENT_USER_ID,
                    "name": AGENT_USER_NAME,
                    "role": "user",
                }
            )
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "detail": str(e)[:200]}


async def add_agent_to_channel(channel_id: str) -> dict:
    """Add the agent as a member of a group channel."""
    try:
        async with _client() as chat:
            channel = chat.channel("messaging", _strip_prefix(channel_id))
            await channel.add_members([AGENT_USER_ID])
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "detail": str(e)[:200]}
