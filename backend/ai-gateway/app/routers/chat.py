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
import json

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.logging_service import log_ai_response
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log    = structlog.get_logger()
router = APIRouter()

_PROMPT_PATH = Path(__file__).parent.parent / "prompts" / "chat_v1.txt"
_RAG_UNAVAILABLE_NOTICE = (
    "La base de connaissance est temporairement inaccessible. "
    "Je peux quand meme vous aider, mais ma reponse ne s'appuiera pas sur les contenus du programme."
)


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
    include_images:       bool = True


class ImageReference(BaseModel):
    url:     str
    caption: str


class ChatResponse(BaseModel):
    reply:  str
    images: list[ImageReference] = Field(default_factory=list)


def _sse_event(event: str, payload: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(payload, ensure_ascii=False)}\n\n"


async def _prepare_chat_context(
    body: ChatRequest,
    llm: BaseLLMClient,
    qdrant: QdrantService,
) -> tuple[str, bool, int, list[dict[str, str]]]:
    rag_chunks_count = 0
    rag_unavailable = False
    image_refs: list[dict[str, str]] = []

    try:
        query_vector = await llm.embed(body.message)
        chunks = await qdrant.search(
            query_vector=query_vector,
            limit=5,
            filter_payload={"subject": body.subject, "grade_level": body.grade_level},
        )
        rag_chunks_count = len(chunks)

        text_chunks = [c for c in chunks if c["payload"].get("chunk_type") != "image"]
        image_chunks = [] if not body.include_images else [c for c in chunks if c["payload"].get("chunk_type") == "image"]

        rag_context = "\n\n---\n\n".join(
            c["payload"].get("text", "") for c in text_chunks
        ) or "Aucun extrait disponible pour ce sujet."

        for ic in image_chunks:
            url = ic["payload"].get("image_url", "")
            caption = ic["payload"].get("text", "")
            if url:
                image_refs.append({"url": url, "caption": caption})
    except Exception as exc:
        log.warning("chat.rag_failed", error=str(exc))
        rag_unavailable = True
        rag_context = (
            "Base de connaissance temporairement inaccessible. "
            "Ne pretends pas t'appuyer sur des extraits du programme dans cette reponse."
        )
        image_refs = []

    rag_images_section = ""
    if image_refs:
        lines = [f'[IMAGE:{ref["url"]}] {ref["caption"]}' for ref in image_refs]
        rag_images_section = "\n\nSchémas et figures pertinents :\n" + "\n".join(lines)

    history_text = "\n".join(
        f"{m.role.capitalize()}: {m.content}"
        for m in body.conversation_history[-10:]
    )

    system_prompt = _PROMPT_PATH.read_text(encoding="utf-8").format(
        subject=body.subject,
        grade_level=body.grade_level,
        country=body.country,
        rag_context=rag_context,
        rag_images_section=rag_images_section,
        conversation_history=history_text,
        user_message=body.message,
    )
    return system_prompt, rag_unavailable, rag_chunks_count, image_refs


@router.post("", response_model=ChatResponse)
async def chat(
    body:    ChatRequest,
    request: Request,
    llm:     Annotated[BaseLLMClient, Depends(get_llm_client)],
    qdrant:  Annotated[QdrantService, Depends(get_qdrant_service)],
) -> ChatResponse:
    user_id = request.state.user.get("uid", "anonymous")
    system_prompt, rag_unavailable, rag_chunks_count, image_refs = await _prepare_chat_context(
        body=body,
        llm=llm,
        qdrant=qdrant,
    )

    messages = [{"role": "user", "content": body.message}]

    try:
        reply, usage = await llm.chat(messages, system_prompt=system_prompt)
    except Exception as exc:
        log.error("chat.llm_error", error=str(exc))
        raise HTTPException(status_code=502, detail="Erreur du service IA") from exc

    if rag_unavailable:
        reply = f"{_RAG_UNAVAILABLE_NOTICE}\n\n{reply}"

    await log_ai_response(
        user_id=user_id,
        session_id=body.session_id,
        endpoint="chat",
        model="llm",
        prompt=body.message,
        response=reply,
        prompt_tokens=usage.prompt_tokens,
        completion_tokens=usage.completion_tokens,
        extra={
            "subject": body.subject,
            "rag_chunks_used": rag_chunks_count,
            "rag_unavailable": rag_unavailable,
        },
    )

    return ChatResponse(reply=reply, images=[ImageReference(**ref) for ref in image_refs])


@router.post("/stream")
async def chat_stream(
    body: ChatRequest,
    request: Request,
    llm: Annotated[BaseLLMClient, Depends(get_llm_client)],
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)],
) -> StreamingResponse:
    user_id = request.state.user.get("uid", "anonymous")
    system_prompt, rag_unavailable, rag_chunks_count, image_refs = await _prepare_chat_context(
        body=body,
        llm=llm,
        qdrant=qdrant,
    )
    messages = [{"role": "user", "content": body.message}]

    async def event_generator():
        full_reply = ""
        usage_prompt_tokens = 0
        usage_completion_tokens = 0

        try:
            if image_refs:
                yield _sse_event("images", {"images": image_refs})

            if rag_unavailable:
                prefix = f"{_RAG_UNAVAILABLE_NOTICE}\n\n"
                full_reply += prefix
                yield _sse_event("delta", {"text": prefix})

            async for chunk in llm.chat_stream(messages, system_prompt=system_prompt):
                full_reply += chunk
                yield _sse_event("delta", {"text": chunk})

            await log_ai_response(
                user_id=user_id,
                session_id=body.session_id,
                endpoint="chat_stream",
                model="llm",
                prompt=body.message,
                response=full_reply,
                prompt_tokens=usage_prompt_tokens,
                completion_tokens=usage_completion_tokens,
                extra={
                    "subject": body.subject,
                    "rag_chunks_used": rag_chunks_count,
                    "rag_unavailable": rag_unavailable,
                },
            )
            yield _sse_event("done", {"reply": full_reply})
        except Exception as exc:
            log.error("chat.stream_error", error=str(exc))
            yield _sse_event("error", {"message": "Erreur du service IA"})

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
