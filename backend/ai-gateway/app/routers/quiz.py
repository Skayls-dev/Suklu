"""
POST /quiz/generate — AI quiz generation for tutors.

Generates a structured quiz grounded in the RAG curriculum content.
Tutors can configure subject, grade, number of questions, difficulty, and types.
"""
import json
from pathlib import Path
from typing import Annotated, Literal

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.logging_service import log_ai_response
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log    = structlog.get_logger()
router = APIRouter()

_PROMPT_PATH  = Path(__file__).parent.parent / "prompts" / "quiz_v1.txt"
_TUTOR_ROLES  = {"tutor", "academic_staff", "super_admin"}


class QuizGenerateRequest(BaseModel):
    topic:         str
    subject:       str
    grade_level:   str
    num_questions: int                                      = Field(default=5, ge=1, le=20)
    difficulty:    Literal["facile", "moyen", "difficile"] = "moyen"
    question_types: list[str] = Field(
        default=["qcm", "vrai_faux"],
        description="Subset of: qcm, vrai_faux, texte_lacunaire, reponse_courte",
    )
    session_id: str = ""


@router.post("/generate")
async def generate_quiz(
    body:    QuizGenerateRequest,
    request: Request,
    llm:     Annotated[BaseLLMClient, Depends(get_llm_client)],
    qdrant:  Annotated[QdrantService, Depends(get_qdrant_service)],
) -> dict:
    user      = request.state.user
    user_role = user.get("role", "")
    user_id   = user.get("uid", "anonymous")

    if user_role not in _TUTOR_ROLES:
        raise HTTPException(status_code=403, detail="Réservé aux tuteurs et au personnel")

    # ── RAG context for the topic ─────────────────────────────────────────────
    try:
        query_vector = await llm.embed(f"{body.topic} {body.subject} {body.grade_level}")
        chunks       = await qdrant.search(
            query_vector=query_vector,
            limit=6,
            filter_payload={"subject": body.subject, "grade_level": body.grade_level},
        )
        rag_context = "\n\n".join(c["payload"].get("text", "") for c in chunks)
    except Exception as exc:
        log.warning("quiz.rag_failed", error=str(exc))
        rag_context = ""

    # ── Build prompt ──────────────────────────────────────────────────────────
    system_prompt = _PROMPT_PATH.read_text(encoding="utf-8").format(
        topic=body.topic,
        subject=body.subject,
        grade_level=body.grade_level,
        num_questions=body.num_questions,
        question_types=", ".join(body.question_types),
        difficulty=body.difficulty,
        rag_context=rag_context or "Aucun extrait disponible — génère un quiz généraliste.",
    )

    try:
        raw, usage = await llm.chat(
            [{"role": "user", "content": "Génère le quiz maintenant."}],
            system_prompt=system_prompt,
            temperature=0.4,
            max_tokens=3000,
        )
    except Exception as exc:
        log.error("quiz.llm_error", error=str(exc))
        raise HTTPException(status_code=502, detail="Erreur du service IA") from exc

    # ── Parse JSON response ───────────────────────────────────────────────────
    try:
        # LLMs sometimes wrap JSON in ```json ... ``` fences
        clean = raw.strip()
        if clean.startswith("```"):
            clean = clean.split("```")[1]
            if clean.startswith("json"):
                clean = clean[4:]
        quiz_data = json.loads(clean.strip())
    except json.JSONDecodeError:
        log.warning("quiz.json_parse_failed", raw=raw[:200])
        raise HTTPException(status_code=502, detail="Réponse IA invalide — réessayez")

    await log_ai_response(
        user_id=user_id,
        session_id=body.session_id,
        endpoint="quiz/generate",
        model="llm",
        prompt=f"{body.topic} / {body.subject}",
        response=raw,
        prompt_tokens=usage.prompt_tokens,
        completion_tokens=usage.completion_tokens,
    )

    return quiz_data
