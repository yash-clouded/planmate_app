"""
Auth router — mints Stream Chat connection tokens for frontend clients.

The frontend authenticates the user with Firebase, then calls POST /stream/token
with the Firebase uid + display name. We upsert the Stream user and return a
JWT the client uses to connect to Stream directly. This replaces the insecure
dev tokens the client used previously.
"""

import logging

from fastapi import APIRouter, HTTPException, Request

from app.services import stream_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stream", tags=["auth"])


@router.post("/token")
async def create_stream_token(request: Request):
    body = await request.json()
    user_id = body.get("user_id")
    name = body.get("name") or user_id

    if not user_id:
        raise HTTPException(status_code=400, detail="user_id required")

    try:
        token = await stream_service.issue_user_token(user_id=user_id, name=name)
        return {"token": token, "user_id": user_id, "name": name}
    except Exception as e:
        logger.exception(f"Failed to issue Stream token for {user_id}")
        raise HTTPException(status_code=500, detail=str(e)[:200])
