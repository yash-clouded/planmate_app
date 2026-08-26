from pydantic import BaseModel
from typing import Optional


class WebhookMessage(BaseModel):
    """Incoming message from Stream Chat webhook."""
    cid: str  # channel ID, e.g. "messaging:group-123"
    message_id: str
    user_id: str
    text: str
    created_at: str


class WebhookPayload(BaseModel):
    """Full Stream Chat webhook payload."""
    event: str
    message: Optional[WebhookMessage] = None


class AgentContext(BaseModel):
    """Context passed to the agent for processing."""
    channel_id: str
    recent_messages: list[dict]
    mention_text: str


class AgentResponse(BaseModel):
    """Agent's structured response."""
    summary: str
    description: str = ""
    intent: str = ""  # movie, trip, dinner, etc.
    options: list[dict] = []
    needs_confirmation: bool = False
    action_type: str = ""  # booking_search, payment_link, info_only


class ToolCall(BaseModel):
    """A tool call the agent wants the backend to execute."""
    tool_name: str
    parameters: dict


class BookingSearchResult(BaseModel):
    """Result from a booking API search."""
    name: str
    price: float
    image_url: str = ""
    details: str = ""
    provider_id: str = ""


class PollRequest(BaseModel):
    """Request to create a group poll."""
    channel_id: str
    question: str
    options: list[str]
    duration_minutes: int = 60


class SOSAlert(BaseModel):
    """SOS alert to broadcast."""
    user_id: str
    user_name: str
    latitude: float
    longitude: float
    message: str = "Emergency SOS activated"
