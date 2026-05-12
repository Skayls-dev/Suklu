from __future__ import annotations

import base64

import structlog
from openai import AsyncOpenAI

from app.config import settings
from app.llm.llm_client import BaseLLMClient

log = structlog.get_logger()


async def caption_image(
    image_bytes: bytes,
    mime_type: str,
    page_text_context: str,
    subject: str,
    grade_level: str,
    llm: BaseLLMClient,
) -> str:
    if settings.llm_provider != "openai":
        log.warning("image_captioner.gemini_not_supported", provider=settings.llm_provider)
        return f"[Schéma de {subject} — {grade_level}] {page_text_context[:200]}".strip()

    try:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY manquant")

        _ = llm
        b64 = base64.b64encode(image_bytes).decode()
        client = AsyncOpenAI(api_key=settings.openai_api_key)
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{b64}",
                                "detail": "low",
                            },
                        },
                        {
                            "type": "text",
                            "text": (
                                f"Tu es un expert en pédagogie pour l'Afrique francophone.\n"
                                f"Cette image provient d'un document de {subject} niveau {grade_level}.\n"
                                f"Contexte textuel de la page : {page_text_context}\n\n"
                                f"Décris ce schéma ou cette figure en 2-3 phrases claires et précises, "
                                f"en français, comme si tu l'expliquais à un élève. "
                                f"Inclus les labels, légendes et relations importantes visibles. "
                                f"Commence directement par la description sans préambule."
                            ),
                        },
                    ],
                }
            ],
            temperature=0.2,
            max_tokens=300,
        )
        text = response.choices[0].message.content or ""
        return text.strip()
    except Exception as exc:  # noqa: BLE001
        log.warning("image_captioner.failed", error=str(exc), subject=subject, grade_level=grade_level)
        fallback = f"[Schéma de {subject} — {grade_level}] {page_text_context[:200]}".strip()
        return fallback