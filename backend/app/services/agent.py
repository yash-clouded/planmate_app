"""
Agent service — calls NVIDIA NIM (Claude-compatible) with tool use.

The agent reads recent group messages, extracts intent and decided details,
then either asks clarifying questions or triggers tool calls (booking search,
payment link generation).
"""

import json
import logging
from typing import Any

import httpx

from app.config import settings
from app.services import redis_store

logger = logging.getLogger(__name__)

AGENT_SYSTEM_PROMPT = """You are PlanMate, an AI agent for trip planning ONLY.
Your ONLY job is to help the group plan trips, outings, travel, hotels, restaurants, movies, and bookings.
You MUST refuse to answer anything unrelated to trip/event planning.
If the user asks about politics, coding, personal advice, or anything else, say: "I only help with trip planning. Ask me about destinations, hotels, restaurants, or bookings!"

RULES:
1. Read the recent conversation and extract what the group has decided.
2. Identify: activity type, date/time, location, budget, headcount.
3. If key info is missing, ask the group ONE clear question.
4. If you have enough info, present 2-3 concrete options as structured tool calls.
5. NEVER book or pay without explicit group confirmation.
6. Keep responses short and actionable.

COMMANDS:
- If user explicitly says "poll" or "create poll", call create_poll tool and ONLY return the poll.
- If user says "summarize", give a concise trip summary.
- If user says "restaurants", call search_restaurants and return results.

AVAILABLE TOOLS:
- search_hotels: search hotels near a location for given dates
- search_movies: search movie showtimes for a given date
- search_restaurants: search restaurants for a cuisine and budget
- generate_payment_link: generate a UPI/payment link for a booking
- create_poll: create a group poll for a decision

Respond with a JSON object:
{
  "summary": "short summary",
  "description": "additional context",
  "intent": "trip|movie|dinner|other",
  "needs_confirmation": false,
  "action_type": "booking_search|info_only|poll",
  "tool_calls": [{"tool": "tool_name", "params": {...}}]
}

If the user asks about non-trip topics, set action_type="rejected", summary="I only help with trip planning. Ask me about destinations, hotels, restaurants, or bookings!", and tool_calls=[]."""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_hotels",
            "description": "Search for hotels near a location for given dates",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "City or area name"},
                    "check_in": {"type": "string", "description": "Check-in date (YYYY-MM-DD)"},
                    "check_out": {"type": "string", "description": "Check-out date (YYYY-MM-DD)"},
                    "budget_per_night": {"type": "number", "description": "Max budget per night in INR"},
                    "num_rooms": {"type": "integer", "description": "Number of rooms needed"},
                },
                "required": ["location", "check_in", "check_out"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_movies",
            "description": "Search for movie showtimes at nearby theaters",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"},
                    "date": {"type": "string", "description": "Show date (YYYY-MM-DD)"},
                    "genre": {"type": "string", "description": "Preferred genre if any"},
                },
                "required": ["city", "date"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_restaurants",
            "description": "Search for restaurants matching criteria",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "Area or city"},
                    "cuisine": {"type": "string", "description": "Cuisine type"},
                    "budget": {"type": "string", "description": "Budget range: budget|mid|premium"},
                    "headcount": {"type": "integer", "description": "Number of people"},
                },
                "required": ["location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "generate_payment_link",
            "description": "Generate a payment link for a booking",
            "parameters": {
                "type": "object",
                "properties": {
                    "amount": {"type": "number", "description": "Total amount in INR"},
                    "description": {"type": "string", "description": "Payment description"},
                    "split_count": {"type": "integer", "description": "Split among N people"},
                },
                "required": ["amount", "description"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_poll",
            "description": "Create a group poll for a decision",
            "parameters": {
                "type": "object",
                "properties": {
                    "question": {"type": "string", "description": "The poll question"},
                    "options": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Poll option strings",
                    },
                    "duration_minutes": {
                        "type": "integer",
                        "description": "Poll duration in minutes (default 60)",
                    },
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

    # Detect direct commands
    lower_text = mention_text.lower().strip()
    if lower_text in ("poll", "create poll") or lower_text.startswith("poll "):
        return await _handle_poll_command(channel_id, mention_text)
    elif lower_text in ("summarize", "summary") or lower_text.startswith("summarize "):
        return await _handle_summarize_command(channel_id)
    elif lower_text.startswith("restaurants ") or lower_text.startswith("restaurant "):
        return await _handle_restaurants_command(channel_id, mention_text)
    
    # Default: process as general agent mention
    return await _process_general_mention(channel_id, mention_text)


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
    
    return {
        "summary": f"Poll: {question}",
        "description": "Vote now!",
        "intent": "other",
        "needs_confirmation": False,
        "action_type": "poll",
        "tool_calls": [{
            "tool": "create_poll",
            "params": {
                "question": question,
                "options": options,
                "duration_minutes": 60,
            }
        }],
    }


async def _handle_summarize_command(channel_id: str) -> dict[str, Any]:
    """Handle summarize command - summarize recent conversation."""
    recent = await redis_store.get_recent_messages(channel_id, limit=50)
    if not recent:
        return {
            "summary": "No messages to summarize yet.",
            "description": "Start chatting and I'll summarize the conversation.",
            "intent": "other",
            "needs_confirmation": False,
            "action_type": "info_only",
            "tool_calls": [],
        }
    
    context_str = "\n".join(
        f"[{m.get('user_name', m.get('user_id', '?'))}]: {m['text']}"
        for m in recent
    )
    
    # Use AI to summarize
    summary_prompt = f"""Summarize this trip planning conversation in 2-3 sentences. Focus on what has been decided: activity, date, location, budget, headcount.

Conversation:
{context_str}

Summary:"""
    
    try:
        ai_result = await _call_ai(summary_prompt)
        summary_text = ai_result.get("summary", "Unable to generate summary.")
    except Exception:
        summary_text = f"This group has {len(recent)} recent messages about planning."
    
    return {
        "summary": "Conversation Summary",
        "description": summary_text,
        "intent": "other",
        "needs_confirmation": False,
        "action_type": "info_only",
        "tool_calls": [],
    }


async def _handle_restaurants_command(channel_id: str, text: str) -> dict[str, Any]:
    """Handle restaurants command."""
    # Extract location from text
    location = "the area"
    lower = text.lower()
    for prefix in ["restaurants in", "restaurant in", "restaurants near", "restaurant near"]:
        if lower.startswith(prefix):
            location = text[len(prefix):].strip()
            break
    
    return {
        "summary": f"Restaurants in {location}",
        "description": "Here are some good options for the group:",
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
    """Process a general @agent mention."""
    # 1. Fetch recent messages from Redis
    recent = await redis_store.get_recent_messages(channel_id, limit=50)
    context_str = "\n".join(
        f"[{m.get('user_name', m.get('user_id', '?'))}]: {m['text']}"
        for m in recent
    )

    user_message = f"""Recent group chat:\n{context_str}\n\n---\nThe user just tagged you with: {mention_text}\n\nAnalyze the conversation and respond. ONLY help with trip planning."""

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
    """Call NVIDIA NIM (OpenAI-compatible) API with tool definitions."""
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            f"{settings.nvidia_base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.nvidia_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.nvidia_model,
                "messages": [
                    {"role": "system", "content": AGENT_SYSTEM_PROMPT},
                    {"role": "user", "content": user_message},
                ],
                "tools": TOOLS,
                "tool_choice": "auto",
                "temperature": 0.3,
                "max_tokens": 1024,
            },
        )
        response.raise_for_status()
        data = response.json()

    content = data["choices"][0]["message"]
    raw_text = content.get("content", "")

    # Try to parse structured JSON from the response
    try:
        if "```json" in raw_text:
            json_str = raw_text.split("```json")[1].split("```")[0].strip()
        elif "```" in raw_text:
            json_str = raw_text.split("```")[1].split("```")[0].strip()
        else:
            start = raw_text.find("{")
            end = raw_text.rfind("}") + 1
            if start >= 0 and end > start:
                json_str = raw_text[start:end]
            else:
                json_str = raw_text

        parsed = json.loads(json_str)
    except (json.JSONDecodeError, IndexError):
        parsed = {
            "summary": raw_text[:200] if raw_text else "Let me look into that for the group.",
            "description": "",
            "intent": "other",
            "needs_confirmation": False,
            "action_type": "info_only",
            "tool_calls": [],
        }

    # Also extract tool calls from the API response if present
    api_tool_calls = content.get("tool_calls", [])
    if api_tool_calls and not parsed.get("tool_calls"):
        parsed["tool_calls"] = [
            {
                "tool": tc["function"]["name"],
                "params": json.loads(tc["function"].get("arguments", "{}")),
            }
            for tc in api_tool_calls
        ]

    return parsed


async def _execute_tool(tool_name: str, params: dict) -> dict:
    """Execute a tool call — these hit real or mock APIs."""
    if tool_name == "search_hotels":
        return await _search_hotels(params)
    elif tool_name == "search_movies":
        return await _search_movies(params)
    elif tool_name == "search_restaurants":
        return await _search_restaurants(params)
    elif tool_name == "generate_payment_link":
        return await _generate_payment_link(params)
    elif tool_name == "create_poll":
        return {"status": "poll_created", "params": params}
    else:
        return {"error": f"Unknown tool: {tool_name}"}


async def _search_hotels(params: dict) -> dict:
    """Search hotels — for v1 returns mock data, replace with real API."""
    location = params.get("location", "Unknown")
    budget = params.get("budget_per_night", 3000)

    # TODO: Replace with real hotel API (OYO, Booking.com, etc.)
    return {
        "results": [
            {
                "name": f"Hotel {location} View",
                "price": budget,
                "image_url": "",
                "details": f"2 nights, {params.get('num_rooms', 1)} room(s)",
                "rating": 4.2,
            },
            {
                "name": f"{location} Grand Resort",
                "price": int(budget * 1.3),
                "image_url": "",
                "details": f"2 nights, {params.get('num_rooms', 1)} room(s), breakfast included",
                "rating": 4.5,
            },
            {
                "name": f"Budget Stay {location}",
                "price": int(budget * 0.7),
                "image_url": "",
                "details": f"2 nights, {params.get('num_rooms', 1)} room(s)",
                "rating": 3.8,
            },
        ],
        "location": location,
    }


async def _search_movies(params: dict) -> dict:
    """Search movies — for v1 returns mock data."""
    city = params.get("city", "Unknown")

    # TODO: Replace with real booking API (BookMyShow, Fandango)
    return {
        "results": [
            {
                "name": "Pushpa 2: The Rule",
                "showtimes": ["10:00 AM", "1:30 PM", "6:00 PM", "9:30 PM"],
                "theater": f"PVR {city} Mall",
                "price": 250,
            },
            {
                "name": "War 2",
                "showtimes": ["11:00 AM", "2:00 PM", "7:00 PM"],
                "theater": f"INOX {city} Centre",
                "price": 300,
            },
        ],
        "city": city,
    }


async def _search_restaurants(params: dict) -> dict:
    """Search restaurants — for v1 returns mock data."""
    location = params.get("location", "Unknown")

    # TODO: Replace with real restaurant API (Zomato, Google Places)
    return {
        "results": [
            {
                "name": f"Spice Garden {location}",
                "cuisine": params.get("cuisine", "Multi-cuisine"),
                "price_for_two": 800,
                "rating": 4.3,
                "details": "Indoor seating, family-friendly",
            },
            {
                "name": f"The {location} Kitchen",
                "cuisine": params.get("cuisine", "North Indian"),
                "price_for_two": 1200,
                "rating": 4.6,
                "details": "Rooftop dining, live music",
            },
        ],
        "location": location,
    }


async def _generate_payment_link(params: dict) -> dict:
    """Generate a payment link — for v1 returns mock UPI link."""
    amount = params.get("amount", 0)
    description = params.get("description", "PlanMate Booking")
    split_count = params.get("split_count", 1)
    per_person = amount // split_count if split_count > 0 else amount

    # TODO: Replace with real Razorpay/Stripe integration
    return {
        "payment_url": f"upi://pay?pa=planmate@upi&pn=PlanMate&am={per_person}&tn={description}",
        "amount": amount,
        "per_person": per_person,
        "split_count": split_count,
        "description": description,
        "status": "link_generated",
    }


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
                    payment = await _generate_payment_link({
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
