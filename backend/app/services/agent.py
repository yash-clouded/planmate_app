"""
Agent service — calls NVIDIA NIM (Claude-compatible) with tool use.

The agent reads recent group messages, extracts intent and decided details,
then either asks clarifying questions or triggers tool calls (booking search,
payment link generation).
"""

import json
import logging
import re
from datetime import datetime, timezone
from typing import Any

import httpx

from app.config import settings
from app.services.external_api import external_api
from app.services import redis_store

logger = logging.getLogger(__name__)

AGENT_SYSTEM_PROMPT = """PlanMate: AI trip & event planner for groups.
Output JSON only:
{
  "summary": "1-sentence summary or response",
  "description": "brief details or clarifying question",
  "intent": "trip|movie|dinner|other",
  "needs_confirmation": false,
  "action_type": "booking_search|info_only|poll|rejected",
  "tool_calls": [{"tool": "tool_name", "params": {...}}]
}
Rules:
- Keep responses short, concise, and actionable.
- IMPORTANT: The user message already contains what the user said. Use it directly.
  If they said "eat first then go bowling in Koramangala", respond with something like
  "Got it — food first, then bowling in Koramangala. Let me find options."
- Only ask 1 clear question if essential info is genuinely missing (no location at all, no activity at all).
- Do NOT ask users to repeat information they already provided.
- Do NOT re-greet or restart the conversation. Continue from context.
- For unrelated topics (politics, coding, personal), set action_type="rejected", summary="I only help with trip, hotel, restaurant, and event planning."
"""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_hotels",
            "description": "Search hotels near a location for dates",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string"},
                    "check_in": {"type": "string", "description": "YYYY-MM-DD"},
                    "check_out": {"type": "string", "description": "YYYY-MM-DD"},
                    "budget_per_night": {"type": "number"},
                    "num_rooms": {"type": "integer"},
                },
                "required": ["location", "check_in", "check_out"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_movies",
            "description": "Search movie showtimes",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string"},
                    "date": {"type": "string", "description": "YYYY-MM-DD"},
                    "genre": {"type": "string"},
                },
                "required": ["city", "date"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_restaurants",
            "description": "Search restaurants by area and cuisine",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string"},
                    "cuisine": {"type": "string"},
                    "budget": {"type": "string", "description": "budget|mid|premium"},
                    "headcount": {"type": "integer"},
                },
                "required": ["location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "generate_payment_link",
            "description": "Generate payment/UPI link for booking",
            "parameters": {
                "type": "object",
                "properties": {
                    "amount": {"type": "number"},
                    "description": {"type": "string"},
                    "split_count": {"type": "integer"},
                },
                "required": ["amount", "description"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_poll",
            "description": "Create a group decision poll",
            "parameters": {
                "type": "object",
                "properties": {
                    "question": {"type": "string"},
                    "options": {"type": "array", "items": {"type": "string"}},
                    "duration_minutes": {"type": "integer"},
                },
                "required": ["question", "options"],
            },
        },
    },
]


async def process_mention(channel_id: str, mention_text: str) -> dict[str, Any]:
    """
    Process an @agent mention: fetch context, call the AI, execute tools, return response.
    """
    # Rate limit check: max 10 requests per minute per channel
    if not await _check_rate_limit(channel_id):
        return {
            "summary": "Rate limit exceeded",
            "description": "Please wait a minute before mentioning the agent again.",
            "intent": "other",
            "needs_confirmation": False,
            "action_type": "rejected",
            "tool_calls": [],
        }

    # Strip @agent/@planmate tags to get the clean user intent
    clean_text = re.sub(r'@planmate\b|@agent\b', '', mention_text, flags=re.IGNORECASE).strip()

    # Detect direct commands
    lower_text = clean_text.lower().strip()
    if lower_text in ("poll", "create poll") or lower_text.startswith("poll "):
        return await _handle_poll_command(channel_id, clean_text)
    elif lower_text in ("summarize", "summary") or lower_text.startswith("summarize "):
        return await _handle_summarize_command(channel_id)
    elif lower_text.startswith("restaurants ") or lower_text.startswith("restaurant "):
        return await _handle_restaurants_command(channel_id, clean_text)
    
    # Default: process as general agent mention
    return await _process_general_mention(channel_id, clean_text)


async def _check_rate_limit(channel_id: str) -> bool:
    """Check if channel is rate limited. Returns True if allowed."""
    try:
        r = await redis_store.get_redis()
        key = f"rate_limit:{channel_id}"
        current = await r.incr(key)
        if current == 1:
            await r.expire(key, 60)
        return current <= 10
    except Exception:
        return True  # Allow if Redis is down


async def _handle_poll_command(channel_id: str, text: str) -> dict[str, Any]:
    """Handle direct poll command."""
    # Extract question and options from text
    # Format: "poll Question here | Option1 | Option2 | Option3"
    # or just "poll" for a default poll
    parts = text.split("|")
    if len(parts) >= 3:
        question = parts[0].replace("poll", "").replace("Poll", "").strip()
        options = [p.strip() for p in parts[1:]]
    else:
        question = text.replace("poll", "").replace("Poll", "").strip() or "What should we do?"
        options = ["Option A", "Option B", "Option C"]

    poll_id = f"poll-{int(datetime.now(timezone.utc).timestamp() * 1000)}"
    try:
        await redis_store.store_poll(
            channel_id=channel_id,
            poll_id=poll_id,
            question=question,
            options=options,
            duration_minutes=60,
        )
    except Exception:
        pass

    return {
        "summary": f"Poll: {question}",
        "description": "Vote now!",
        "intent": "other",
        "needs_confirmation": False,
        "action_type": "poll",
        # tool_calls: consumed by the Stream webhook path to post a poll card.
        # tool_results: consumed by the direct-command frontend, which renders
        # the poll card from result['tool_results'] (same {tool, params} shape).
        "tool_calls": [{
            "tool": "create_poll",
            "params": {
                "question": question,
                "options": options,
                "duration_minutes": 60,
            }
        }],
        "tool_results": [{
            "tool": "create_poll",
            "params": {
                "question": question,
                "options": options,
                "duration_minutes": 60,
            }
        }],
        "poll_id": poll_id,
    }


async def _handle_summarize_command(channel_id: str) -> dict[str, Any]:
    """Handle summarize command - summarize recent conversation with minimal tokens."""
    recent = await redis_store.get_recent_messages(channel_id, limit=8)
    if not recent:
        return {
            "summary": "No messages to summarize yet.",
            "description": "Start chatting and I'll summarize the group's decisions.",
            "intent": "other",
            "needs_confirmation": False,
            "action_type": "info_only",
            "tool_calls": [],
        }

    context_str = "\n".join(
        f"{m.get('user_name', m.get('user_id', 'user'))}: {m['text']}"
        for m in recent
    )

    summary_prompt = f"Summarize decisions (activity, date, location, budget, headcount) in 2 short sentences:\n{context_str}"

    try:
        ai_result = await _call_ai(summary_prompt)
        summary_text = ai_result.get("summary", "Summary unavailable.")
    except Exception:
        summary_text = f"The group has {len(recent)} recent messages."

    return {
        "summary": "Trip Summary",
        "description": summary_text,
        "intent": "other",
        "needs_confirmation": False,
        "action_type": "info_only",
        "tool_calls": [],
    }


async def _handle_restaurants_command(channel_id: str, text: str) -> dict[str, Any]:
    """Handle restaurants command."""
    location = "the area"
    lower = text.lower()
    for prefix in ["restaurants in", "restaurant in", "restaurants near", "restaurant near"]:
        if lower.startswith(prefix):
            location = text[len(prefix):].strip()
            break

    return {
        "summary": f"Restaurants in {location}",
        "description": "Here are top options for the group:",
        "intent": "dinner",
        "needs_confirmation": True,
        "action_type": "booking_search",
        "tool_calls": [{
            "tool": "search_restaurants",
            "params": {
                "location": location,
                "cuisine": "any",
                "budget": "mid",
                "headcount": 4,
            }
        }],
    }


async def _process_general_mention(channel_id: str, mention_text: str) -> dict[str, Any]:
    """Process a general @agent mention with minimal token context."""
    # 1. Fetch recent messages from Redis (last 10 messages for better context)
    recent = await redis_store.get_recent_messages(channel_id, limit=10)
    context_lines = [
        f"{m.get('user_name', m.get('user_id', 'user'))}: {m['text']}"
        for m in recent if m.get('text')
    ]
    context_str = "\n".join(context_lines)

    # The mention_text is already cleaned (no @agent tags) and represents
    # the user's actual request. Build context so the LLM understands the
    # full conversation and can respond to the specific request.
    user_message = (
        f"You are PlanMate, an AI trip & event planner for groups.\n"
        f"Recent group chat:\n{context_str}\n\n"
        f"User request: {mention_text}\n\n"
        f"Respond directly to the user's request. If they gave clear details "
        f"(location, activity, preferences), use them — do NOT ask for info "
        f"they already provided. Only ask clarifying questions if something "
        f"essential is truly missing."
    )

    # 2. Call NVIDIA NIM API
    agent_reply = await _call_ai(user_message)

    # 3. Execute any tool calls
    tool_results = []
    for tc in agent_reply.get("tool_calls", []):
        result = await _execute_tool(tc["tool"], tc.get("params", {}))
        tool_results.append({"tool": tc["tool"], "result": result})

    # 4. Store agent state for confirmation flow
    if agent_reply.get("needs_confirmation") or agent_reply.get("action_type") == "booking_search":
        await redis_store.store_agent_state(channel_id, {
            "intent": agent_reply.get("intent", ""),
            "action_type": agent_reply.get("action_type", ""),
            "tool_results": tool_results,
            "summary": agent_reply.get("summary", ""),
        })

    return {
        "summary": agent_reply.get("summary", ""),
        "description": agent_reply.get("description", ""),
        "intent": agent_reply.get("intent", ""),
        "action_type": agent_reply.get("action_type", "info_only"),
        "needs_confirmation": agent_reply.get("needs_confirmation", False),
        "tool_results": tool_results,
    }


async def _call_ai(user_message: str) -> dict[str, Any]:
    """Call NVIDIA NIM (OpenAI-compatible) API with model fallback and token budget."""
    models_to_try = [
        settings.nvidia_model or "deepseek-ai/deepseek-v4.1-flash",
    ]

    last_error = None
    for model_name in models_to_try:
        try:
            url = f"{settings.nvidia_base_url}/chat/completions"
            payload = {
                "model": model_name,
                "messages": [
                    {"role": "system", "content": AGENT_SYSTEM_PROMPT},
                    {"role": "user", "content": user_message},
                ],
                "tools": TOOLS,
                "tool_choice": "auto",
                "temperature": 0.2,
                "max_tokens": 1024,
            }
            logger.info(f"Calling NVIDIA API: model={model_name}")
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    url,
                    headers={
                        "Authorization": f"Bearer {settings.nvidia_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                if response.status_code != 200:
                    logger.warning(f"Model {model_name} returned {response.status_code}: {response.text[:200]}")
                    last_error = response.text
                    continue

                data = response.json()

            content = data["choices"][0]["message"]
            raw_text = content.get("content") or ""
            api_tool_calls = content.get("tool_calls") or []

            # Parse structured JSON from the response
            parsed = None
            if raw_text:
                try:
                    if "```json" in raw_text:
                        json_str = raw_text.split("```json")[1].split("```")[0].strip()
                    elif "```" in raw_text:
                        json_str = raw_text.split("```")[1].split("```")[0].strip()
                    else:
                        start = raw_text.find("{")
                        end = raw_text.rfind("}") + 1
                        json_str = raw_text[start:end] if (start >= 0 and end > start) else raw_text

                    parsed = json.loads(json_str)
                except (json.JSONDecodeError, IndexError):
                    pass

            if not isinstance(parsed, dict):
                parsed = {
                    "summary": raw_text[:200] if raw_text else "Looking into options for the group.",
                    "description": "",
                    "intent": "trip",
                    "needs_confirmation": False,
                    "action_type": "booking_search" if api_tool_calls else "info_only",
                    "tool_calls": [],
                }

            # Extract tool calls from response
            if api_tool_calls and not parsed.get("tool_calls"):
                parsed["tool_calls"] = [
                    {
                        "tool": tc["function"]["name"],
                        "params": json.loads(tc["function"].get("arguments", "{}")),
                    }
                    for tc in api_tool_calls
                    if "function" in tc
                ]
                if parsed.get("action_type") == "info_only":
                    parsed["action_type"] = "booking_search"

            return parsed
        except Exception as e:
            logger.warning(f"Error calling model {model_name}: {e}")
            last_error = str(e)
            continue

    logger.error(f"All AI models failed. Last error: {last_error}")
    return {
        "summary": "I'm having trouble connecting right now. Please try again in a moment.",
        "description": str(last_error)[:180] if last_error else "",
        "intent": "other",
        "needs_confirmation": False,
        "action_type": "rejected",
        "tool_calls": [],
        "error": str(last_error),
    }


async def _execute_tool(tool_name: str, params: dict) -> dict:
    """Execute a tool call — these hit real or mock APIs."""
    if tool_name == "search_hotels":
        return await external_api.search_hotels(params)
    elif tool_name == "search_movies":
        return await external_api.search_movies(params)
    elif tool_name == "search_restaurants":
        return await external_api.search_restaurants(params)
    elif tool_name == "generate_payment_link":
        return await external_api.generate_razorpay_payment_link(params)
    elif tool_name == "create_poll":
        return {"status": "poll_created", "params": params}
    else:
        return {"error": f"Unknown tool: {tool_name}"}


async def confirm_booking(channel_id: str) -> dict:
    """Confirm a pending booking after group approval."""
    state = await redis_store.get_agent_state(channel_id)
    if not state:
        return {"error": "No pending booking to confirm"}

    # Execute the payment link generation for the confirmed booking
    if state.get("tool_results"):
        for tr in state["tool_results"]:
            if tr["tool"] in ("search_hotels", "search_movies", "search_restaurants"):
                results = tr["result"].get("results", [])
                if results:
                    price = results[0].get("price", 0) * 2  # 2 nights
                    payment = await external_api.generate_razorpay_payment_link({
                        "amount": price,
                        "description": f"Booking at {results[0]['name']}",
                        "split_count": 6,
                    })
                    await redis_store.clear_agent_state(channel_id)
                    return {
                        "status": "confirmed",
                        "booking": results[0],
                        "payment": payment,
                    }

    await redis_store.clear_agent_state(channel_id)
    return {"status": "confirmed", "message": "Booking confirmed!"}
