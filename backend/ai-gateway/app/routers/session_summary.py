from pathlib import Path
import json
from typing import Annotated, Literal

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.logging_service import log_ai_response
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log = structlog.get_logger()
router = APIRouter()

_PROMPT_PATH = Path(__file__).parent.parent / 'prompts' / 'session_summary_v1.txt'
_ALLOWED_ROLES = {'tutor', 'student', 'parent', 'academic_staff', 'super_admin'}


class RecommendedExercise(BaseModel):
    title: str
    description: str
    difficulty: Literal['facile', 'moyen', 'difficile']
    estimated_duration_minutes: int


class SessionSummaryResult(BaseModel):
    topics_covered: list[str]
    key_concepts_mastered: list[str]
    learning_gaps: list[str]
    recommended_exercises: list[RecommendedExercise]
    next_session_suggestion: str
    encouragement_message: str


class SessionSummaryRequest(BaseModel):
    session_id: str
    subject: str
    grade_level: str
    duration_minutes: int
    tutor_notes: str = ''
    session_chat_history: str = ''
    country: str = 'Sénégal'


class SessionSummaryResponse(BaseModel):
    summary: SessionSummaryResult
    session_id: str


def _extract_json_object(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith('```'):
        cleaned = cleaned.replace('```json', '').replace('```', '').strip()

    parsed = json.loads(cleaned)
    if not isinstance(parsed, dict):
        raise ValueError('Expected top-level JSON object')
    return parsed


def _fallback_summary() -> dict:
    return {
        'summary': {
            'topics_covered': ['Révision générale du chapitre'],
            'key_concepts_mastered': ['Compréhension partielle des notions vues'],
            'learning_gaps': ['Consolidation des bases et entraînement recommandé'],
            'recommended_exercises': [
                {
                    'title': 'Exercices fondamentaux',
                    'description': 'Reprendre les exercices de base du chapitre avec correction guidée.',
                    'difficulty': 'facile',
                    'estimated_duration_minutes': 15,
                },
                {
                    'title': 'Application dirigée',
                    'description': 'Résoudre 2 à 3 problèmes d\'application avec étapes détaillées.',
                    'difficulty': 'moyen',
                    'estimated_duration_minutes': 20,
                },
            ],
            'next_session_suggestion': 'Commencer par une vérification rapide des acquis puis monter en difficulté.',
            'encouragement_message': 'Bonne progression. Continue avec régularité et confiance.',
        },
    }


@router.post('', response_model=SessionSummaryResponse)
async def session_summary(
    body: SessionSummaryRequest,
    request: Request,
    llm: Annotated[BaseLLMClient, Depends(get_llm_client)],
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)],
) -> SessionSummaryResponse:
    user = getattr(request.state, 'user', {}) or {}
    role = user.get('role')
    if role is not None and role not in _ALLOWED_ROLES:
        raise HTTPException(status_code=403, detail='Rôle non autorisé')

    rag_context = 'Aucun extrait disponible pour ce sujet.'
    rag_unavailable = False

    try:
        query_vector = await llm.embed(
            f"{body.subject} {body.grade_level} {body.tutor_notes} {body.session_chat_history}".strip(),
        )
        chunks = await qdrant.search(
            query_vector=query_vector,
            limit=5,
            filter_payload={'subject': body.subject, 'grade_level': body.grade_level},
        )
        rag_context = '\n\n---\n\n'.join(c['payload'].get('text', '') for c in chunks) or rag_context
    except Exception as exc:  # noqa: BLE001
        rag_unavailable = True
        log.warning('session_summary.rag_failed', error=str(exc))

    system_prompt = _PROMPT_PATH.read_text(encoding='utf-8').format(
        subject=body.subject,
        grade_level=body.grade_level,
        duration_minutes=body.duration_minutes,
        tutor_notes=body.tutor_notes or 'Aucune note fournie',
        session_chat_history=body.session_chat_history or 'Non disponible',
        rag_context=rag_context,
    )

    try:
        raw_response, usage = await llm.chat(
            messages=[{'role': 'user', 'content': 'Génère le résumé de session.'}],
            system_prompt=system_prompt,
            temperature=0.3,
            response_format='json_object',
        )
    except Exception as exc:
        log.error('session_summary.llm_error', error=str(exc))
        raise HTTPException(status_code=502, detail='Erreur du service IA') from exc

    try:
        parsed = _extract_json_object(raw_response)
        summary_raw = parsed.get('summary', parsed)
        summary = SessionSummaryResult.model_validate(summary_raw)
    except Exception as exc:  # noqa: BLE001
        log.warning('session_summary.json_parse_failed', error=str(exc))
        fallback = _fallback_summary()['summary']
        summary = SessionSummaryResult.model_validate(fallback)

    await log_ai_response(
        user_id=user.get('uid', 'internal-service'),
        session_id=body.session_id,
        endpoint='session_summary',
        model='llm',
        prompt=system_prompt[:700],
        response=summary.model_dump_json(ensure_ascii=False),
        prompt_tokens=usage.prompt_tokens if 'usage' in locals() else 0,
        completion_tokens=usage.completion_tokens if 'usage' in locals() else 0,
        extra={
            'subject': body.subject,
            'grade_level': body.grade_level,
            'rag_unavailable': rag_unavailable,
        },
    )

    return SessionSummaryResponse(summary=summary, session_id=body.session_id)
