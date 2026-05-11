"""
POST /diagnostic — AI-guided student diagnostic assessment.

Flow:
1. Client sends subject + grade_level + conversation_history.
2. We load the versioned prompt template, inject variables.
3. LLM returns the next question or the final summary.
4. We log the exchange to Firestore.
"""
from pathlib import Path
import json
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.logging_service import log_ai_response

log    = structlog.get_logger()
router = APIRouter()

_PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "diagnostic_v1.txt"


class Message(BaseModel):
    role:    str  # "user" | "assistant"
    content: str


class DiagnosticRequest(BaseModel):
    subject:              str
    grade_level:          str
    conversation_history: list[Message] = []
    session_id:           str           = ""
    max_questions:        int           = 10


class DiagnosticResponse(BaseModel):
    raw: str


def _build_history_text(messages: list[Message]) -> str:
    return "\n".join(f"{m.role.capitalize()}: {m.content}" for m in messages)


def _extract_json_object(text: str) -> dict:
    """Extract and parse the first JSON object from a model response."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.replace("```json", "").replace("```", "").strip()

    # Fast path when response is already a clean JSON object.
    try:
        parsed = json.loads(cleaned)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass

    # Fallback: find the first '{' and try progressive decode until valid JSON is found.
    start = cleaned.find("{")
    if start == -1:
        raise ValueError("No JSON object found in diagnostic response")

    decoder = json.JSONDecoder()
    probe = cleaned[start:]
    for i in range(len(probe)):
        chunk = probe[: i + 1]
        try:
            parsed, _ = decoder.raw_decode(chunk)
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            continue

    raise ValueError("Unable to parse diagnostic JSON object")


@router.post("", response_model=DiagnosticResponse)
async def run_diagnostic(
    body:    DiagnosticRequest,
    request: Request,
    llm:     Annotated[BaseLLMClient, Depends(get_llm_client)],
) -> DiagnosticResponse:
    user_id = request.state.user.get("uid", "anonymous")

    system_prompt = _PROMPT_PATH.read_text(encoding="utf-8").format(
        subject=body.subject,
        grade_level=body.grade_level,
        max_questions=body.max_questions,
        conversation_history=_build_history_text(body.conversation_history),
    )

    messages = [{"role": "user", "content": "Commence le diagnostic."}]
    if body.conversation_history:
        messages = [{"role": m.role, "content": m.content} for m in body.conversation_history]

    try:
        response_text, usage = await llm.chat(
            messages,
            system_prompt=system_prompt,
            temperature=0.1,
            response_format="json_object",
        )
    except Exception as exc:
        log.error("diagnostic.llm_error", error=str(exc))
        raise HTTPException(status_code=502, detail="Erreur du service IA") from exc

    try:
        parsed = _extract_json_object(response_text)
    except Exception as exc:
        log.warning("diagnostic.invalid_json", error=str(exc), raw=response_text[:700])
        parsed = {
            "question": "Je n'ai pas pu analyser la réponse. Peux-tu reformuler en une phrase simple ?",
            "feedback": "Merci pour ta réponse.",
            "is_complete": False,
            "summary": None,
        }

    normalized_raw = json.dumps(parsed, ensure_ascii=False)

    await log_ai_response(
        user_id=user_id,
        session_id=body.session_id,
        endpoint="diagnostic",
        model="llm",
        prompt=system_prompt[:500],
        response=normalized_raw,
        prompt_tokens=usage.prompt_tokens,
        completion_tokens=usage.completion_tokens,
    )

    return DiagnosticResponse(raw=normalized_raw)
