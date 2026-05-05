"""
POST /diagnostic — AI-guided student diagnostic assessment.

Flow:
1. Client sends subject + grade_level + conversation_history.
2. We load the versioned prompt template, inject variables.
3. LLM returns the next question or the final summary.
4. We log the exchange to Firestore.
"""
from pathlib import Path
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
        response_text, usage = await llm.chat(messages, system_prompt=system_prompt)
    except Exception as exc:
        log.error("diagnostic.llm_error", error=str(exc))
        raise HTTPException(status_code=502, detail="Erreur du service IA") from exc

    await log_ai_response(
        user_id=user_id,
        session_id=body.session_id,
        endpoint="diagnostic",
        model="llm",
        prompt=system_prompt[:500],
        response=response_text,
        prompt_tokens=usage.prompt_tokens,
        completion_tokens=usage.completion_tokens,
    )

    return DiagnosticResponse(raw=response_text)
