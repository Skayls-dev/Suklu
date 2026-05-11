"""
SafetyFilterMiddleware

Runs on every inbound request to /chat, /diagnostic, /quiz/generate.
Checks the request body for inappropriate content before it reaches
the LLM, protecting minors on the platform.

Strategy:
  1. Keyword blocklist (fast, zero-cost, immediate)
  2. Flagged content written to Firestore /flagged_content for review by
     designated content moderator accounts (isContentModerator=true flag).
  3. Pluggable: replace _is_unsafe() with OpenAI Moderation API or
     Google SafeSearch for higher accuracy in a future iteration.

This middleware also verifies the Firebase ID token and injects the
decoded user claims into request.state so route handlers don't repeat
the verification.
"""
import json
import re
import uuid
from datetime import UTC, datetime
from typing import Callable

import firebase_admin.auth as fb_auth
import structlog
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.config import settings

log = structlog.get_logger()

# ── Blocklist ─────────────────────────────────────────────────────────────────
# Security policy — extend based on observed misuse patterns.
_BLOCKED_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r'\b(porn|porno|xxx|nude|nudité)\b',              re.IGNORECASE), "explicit_content"),
    (re.compile(r'\b(suicide|automutilation|kill yourself)\b',    re.IGNORECASE), "self_harm"),
    (re.compile(r'\b(terroris[mt]e?|jihadiste?|bombe artisanale)\b', re.IGNORECASE), "violence"),
]

# Endpoints that require auth token verification
_PROTECTED_PREFIXES = ("/chat", "/diagnostic", "/quiz", "/ingest")


def _check_content(text: str) -> tuple[bool, str]:
    """Returns (is_unsafe, matched_pattern_category)."""
    for pattern, category in _BLOCKED_PATTERNS:
        if pattern.search(text):
            return True, category
    return False, ""


async def _flag_content(
    user_id: str,
    path: str,
    content_snippet: str,
    matched_pattern: str,
) -> None:
    """Write a flagged_content record (fire-and-forget, never blocks response)."""
    try:
        from google.cloud import firestore
        db = firestore.AsyncClient()
        await db.collection("flagged_content").add({
            "id":             str(uuid.uuid4()),
            "userId":         user_id,
            "endpoint":       path,
            "contentSnippet": content_snippet[:300],
            "matchedPattern": matched_pattern,
            "status":         "pending_review",
            "createdAt":      datetime.now(UTC),
        })
    except Exception as exc:  # noqa: BLE001
        log.warning("safety_filter.flag_write_failed", error=str(exc))


class SafetyFilterMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        path = request.url.path

        # ── Auth token verification ───────────────────────────────────────────
        if any(path.startswith(prefix) for prefix in _PROTECTED_PREFIXES):
            # Dev bypass — skip token verification when SKIP_AUTH=true
            if settings.skip_auth:
                request.state.user = {
                    "uid": "dev-user",
                    "email": "dev@local",
                    "role": request.headers.get("X-Dev-Role", "student"),
                }
            else:
                auth_header = request.headers.get("Authorization", "")
                if not auth_header.startswith("Bearer "):
                    return JSONResponse(
                        status_code=401,
                        content={"detail": "Token d'authentification manquant"},
                    )
                token = auth_header[len("Bearer "):]
                try:
                    decoded = fb_auth.verify_id_token(token)
                    request.state.user = decoded
                except Exception:
                    return JSONResponse(
                        status_code=401,
                        content={"detail": "Token invalide ou expiré"},
                    )

        # ── Content safety check (POST only) ─────────────────────────────────
        if settings.content_moderation_enabled and request.method == "POST":
            try:
                body_bytes = await request.body()
                body_text  = body_bytes.decode("utf-8", errors="ignore")

                # Extract human-readable string fields from JSON bodies
                try:
                    body_json  = json.loads(body_text)
                    check_text = " ".join(
                        str(v) for v in body_json.values()
                        if isinstance(v, str)
                    )
                except (json.JSONDecodeError, AttributeError):
                    check_text = body_text

                is_unsafe, matched_pattern = _check_content(check_text)

                if is_unsafe:
                    user_id = getattr(getattr(request, "state", None), "user", {}).get("uid", "unknown")
                    log.warning(
                        "safety_filter.blocked",
                        path=path,
                        user_id=user_id,
                        pattern=matched_pattern,
                    )
                    # Persist for human review — does NOT block the error response
                    import asyncio
                    asyncio.create_task(
                        _flag_content(user_id, path, check_text, matched_pattern)
                    )
                    return JSONResponse(
                        status_code=400,
                        content={"detail": "Contenu inapproprié détecté"},
                    )

                # Request.body() caches bytes in Starlette, so downstream
                # handlers can parse the same body without manually overriding
                # request._receive (which breaks StreamingResponse disconnect checks).

            except Exception as exc:  # noqa: BLE001
                log.error("safety_filter.error", error=str(exc))

        return await call_next(request)
