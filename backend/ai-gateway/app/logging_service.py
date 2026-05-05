"""
AI response logger.

Every AI-generated response is stored in /ai_logs/{auto-id} with:
  userId, sessionId, endpoint, prompt_tokens, completion_tokens, timestamp.

The Firestore write is fire-and-forget — we log errors but never block the
response to the client because of a logging failure.
"""
import asyncio
from datetime import UTC, datetime
from typing import Any

import structlog
from google.cloud import firestore  # via firebase-admin

log = structlog.get_logger()


async def log_ai_response(
    *,
    user_id: str,
    session_id: str,
    endpoint: str,
    model: str,
    prompt: str,
    response: str,
    prompt_tokens: int = 0,
    completion_tokens: int = 0,
    extra: dict[str, Any] | None = None,
) -> None:
    """Write an AI interaction record to /ai_logs in Firestore (async, best-effort)."""
    try:
        db = firestore.AsyncClient()
        doc = {
            "userId":           user_id,
            "sessionId":        session_id,
            "endpoint":         endpoint,
            "model":            model,
            "promptSnippet":    prompt[:500],   # store only first 500 chars
            "responseSnippet":  response[:500],
            "promptTokens":     prompt_tokens,
            "completionTokens": completion_tokens,
            "timestamp":        datetime.now(UTC),
            **(extra or {}),
        }
        await db.collection("ai_logs").add(doc)
    except Exception as exc:  # noqa: BLE001
        # Logging must never crash the request
        log.warning("ai_log.write_failed", error=str(exc))
