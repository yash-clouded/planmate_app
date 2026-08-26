"""
Redis-backed rolling window message store for group chats.

Each group keeps the last WINDOW_SIZE messages in a Redis list.
Messages are JSON-encoded dicts with sender, text, timestamp, etc.
"""

import json
from datetime import datetime, timezone

import redis.asyncio as aioredis

from app.config import settings

WINDOW_SIZE = 50  # last N messages per group

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
        )
    return _redis


async def store_message(channel_id: str, message: dict) -> None:
    """Append a message to the group's rolling window."""
    r = await get_redis()
    key = f"chat:{channel_id}:messages"

    enriched = {
        "user_id": message.get("user_id", ""),
        "user_name": message.get("user_name", ""),
        "text": message.get("text", ""),
        "timestamp": message.get("created_at", datetime.now(timezone.utc).isoformat()),
        "message_id": message.get("message_id", ""),
    }

    await r.rpush(key, json.dumps(enriched))
    await r.ltrim(key, -WINDOW_SIZE, -1)
    await r.expire(key, 86400 * 7)  # TTL 7 days


async def get_recent_messages(channel_id: str, limit: int = 50) -> list[dict]:
    """Get the last `limit` messages for a group."""
    r = await get_redis()
    key = f"chat:{channel_id}:messages"
    raw = await r.lrange(key, -limit, -1)
    return [json.loads(m) for m in raw]


async def store_agent_state(channel_id: str, state: dict) -> None:
    """Store current agent conversation state for a group."""
    r = await get_redis()
    key = f"chat:{channel_id}:agent_state"
    await r.set(key, json.dumps(state), ex=3600 * 2)  # 2hr TTL


async def get_agent_state(channel_id: str) -> dict | None:
    """Get current agent state (last intent, pending confirmation, etc.)."""
    r = await get_redis()
    key = f"chat:{channel_id}:agent_state"
    raw = await r.get(key)
    return json.loads(raw) if raw else None


async def clear_agent_state(channel_id: str) -> None:
    """Clear agent state after confirmation."""
    r = await get_redis()
    key = f"chat:{channel_id}:agent_state"
    await r.delete(key)


async def store_poll(
    channel_id: str,
    poll_id: str,
    question: str,
    options: list[str],
    duration_minutes: int = 60,
) -> None:
    """Store a poll with anonymous votes."""
    r = await get_redis()
    poll_key = f"chat:{channel_id}:poll:{poll_id}"
    poll_data = {
        "question": question,
        "options": json.dumps(options),
        "total_votes": 0,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "duration_minutes": duration_minutes,
    }
    await r.hset(poll_key, mapping=poll_data)
    await r.expire(poll_key, duration_minutes * 60 + 3600)


async def cast_vote(
    channel_id: str, poll_id: str, user_id: str, option_index: int
) -> dict:
    """Cast an anonymous vote. Returns aggregate counts."""
    r = await get_redis()
    vote_key = f"chat:{channel_id}:poll:{poll_id}:votes"
    poll_key = f"chat:{channel_id}:poll:{poll_id}"

    # Store user->vote mapping (anonymous, only for dedup)
    await r.hset(vote_key, user_id, str(option_index))

    # Count totals
    all_votes = await r.hgetall(vote_key)
    poll_raw = await r.hget(poll_key, "options")
    options = json.loads(poll_raw) if poll_raw else []

    counts = {i: 0 for i in range(len(options))}
    for uid, idx in all_votes.items():
        counts[int(idx)] = counts.get(int(idx), 0) + 1

    await r.hset(poll_key, "total_votes", str(len(all_votes)))

    return {
        "options": options,
        "counts": counts,
        "total_votes": len(all_votes),
    }


async def get_polls(channel_id: str) -> list[dict]:
    """Get all active polls for a channel."""
    r = await get_redis()
    pattern = f"chat:{channel_id}:poll:*"
    keys = []
    cursor = 0
    while True:
        cursor, batch = await r.scan(cursor=cursor, match=pattern, count=100)
        keys.extend(batch)
        if cursor == 0:
            break

    polls = []
    for key in keys:
        if key.endswith(":votes"):
            continue
        raw = await r.hgetall(key)
        if not raw:
            continue
        try:
            options = json.loads(raw.get("options", "[]"))
            polls.append({
                "poll_id": key.split(":")[-1],
                "question": raw.get("question", ""),
                "options": options,
                "total_votes": int(raw.get("total_votes", 0)),
                "created_at": raw.get("created_at", ""),
                "duration_minutes": int(raw.get("duration_minutes", 60)),
            })
        except Exception:
            continue

    return polls
