"""
POST /chat — RAG-grounded tutoring chat.

Flow:
1. Embed the user's message.
2. Retrieve top-k chunks from Qdrant for the relevant subject/grade.
3. Inject retrieved context into the versioned prompt template.
4. Stream or return the LLM response.
5. Log to Firestore.
"""
from pathlib import Path
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.logging_service import log_ai_response
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log    = structlog.get_logger()
router = APIRouter()

_PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "chat_v1.txt"


class Message(BaseModel):
    role:    str
    content: str


class ChatRequest(BaseModel):
    message:              str
    subject:              str
    grade_level:          str
    country:              str = "Sénégal"
    conversation_history: list[Message] = []
    session_id:           str = ""


class ChatResponse(BaseModel):
    reply: str


@router.post("", response_model=ChatResponse)
async def chat(
    body:    ChatRequest,
    request: Request,
    llm:     Annotated[BaseLLMClient, Depends(get_llm_client)],
    qdrant:  Annotated[QdrantService, Depends(get_qdrant_service)],
) -> ChatResponse:
    user_id = request.state.user.get("uid", "anonymous")

    # ── RAG retrieval ─────────────────────────────────────────────────────────
    rag_chunks_count = 0
    try:
        query_vector = await llm.embed(body.message)
        chunks       = await qdrant.search(
            query_vector=query_vector,
            limit=5,
            filter_payload={"subject": body.subject, "grade_level": body.grade_level},
        )
        rag_chunks_count = len(chunks)
        rag_context = "\n\n---\n\n".join(
            c["payload"].get("text", "") for c in chunks
        ) or "Aucun extrait disponible pour ce sujet."
    except Exception as exc:
        log.warning("chat.rag_failed", error=str(exc))
        rag_context = "Aucun extrait disponible."

    # ── Build prompt ──────────────────────────────────────────────────────────
    history_text = "\n".join(
        f"{m.role.capitalize()}: {m.content}"
        for m in body.conversation_history[-10:]  # Keep last 10 turns to stay within context window
    )

    system_prompt = _PROMPT_PATH.read_text(encoding="utf-8").format(
        subject=body.subject,
        grade_level=body.grade_level,
        country=body.country,
        rag_context=rag_context,
        conversation_history=history_text,
        user_message=body.message,
    )

    messages = [{"role": "user", "content": body.message}]

    try:
        reply, usage = await llm.chat(messages, system_prompt=system_prompt)
    except Exception as exc:
        log.error("chat.llm_error", error=str(exc))
        raise HTTPException(status_code=502, detail="Erreur du service IA") from exc

    await log_ai_response(
        user_id=user_id,
        session_id=body.session_id,
        endpoint="chat",
        model="llm",
        prompt=body.message,
        response=reply,
        prompt_tokens=usage.prompt_tokens,
        completion_tokens=usage.completion_tokens,
        extra={"subject": body.subject, "rag_chunks_used": rag_chunks_count},
    )

    return ChatResponse(reply=reply)
