"""
LLMClient — provider-agnostic abstraction over OpenAI and Google Gemini.

Switching providers is a single env-var change (LLM_PROVIDER=gemini).
Both providers expose the same interface:
  - chat(messages, system_prompt) → (content, usage)
  - embed(text)                   → list[float]

Usage:
  from app.llm.llm_client import get_llm_client
  client = get_llm_client()
  text, usage = await client.chat([{"role": "user", "content": "Bonjour"}])
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import structlog

from app.config import settings

log = structlog.get_logger()


@dataclass
class LLMUsage:
    prompt_tokens:     int = 0
    completion_tokens: int = 0


class BaseLLMClient(ABC):
    @abstractmethod
    async def chat(
        self,
        messages: list[dict[str, str]],
        system_prompt: str = "",
        temperature: float = 0.3,
        max_tokens: int = 2048,
    ) -> tuple[str, LLMUsage]:
        ...

    @abstractmethod
    async def embed(self, text: str) -> list[float]:
        ...


# ── OpenAI implementation ─────────────────────────────────────────────────────

class OpenAIClient(BaseLLMClient):
    def __init__(self) -> None:
        from openai import AsyncOpenAI
        self._client = AsyncOpenAI(api_key=settings.openai_api_key)

    async def chat(
        self,
        messages: list[dict[str, str]],
        system_prompt: str = "",
        temperature: float = 0.3,
        max_tokens: int = 2048,
    ) -> tuple[str, LLMUsage]:
        all_messages: list[dict[str, str]] = []
        if system_prompt:
            all_messages.append({"role": "system", "content": system_prompt})
        all_messages.extend(messages)

        response = await self._client.chat.completions.create(
            model=settings.openai_model,
            messages=all_messages,  # type: ignore[arg-type]
            temperature=temperature,
            max_tokens=max_tokens,
        )
        content = response.choices[0].message.content or ""
        usage   = LLMUsage(
            prompt_tokens=response.usage.prompt_tokens if response.usage else 0,
            completion_tokens=response.usage.completion_tokens if response.usage else 0,
        )
        return content, usage

    async def embed(self, text: str) -> list[float]:
        response = await self._client.embeddings.create(
            model=settings.openai_embedding_model,
            input=text,
        )
        return response.data[0].embedding


# ── Google Gemini implementation ──────────────────────────────────────────────

class GeminiClient(BaseLLMClient):
    def __init__(self) -> None:
        import google.generativeai as genai
        genai.configure(api_key=settings.gemini_api_key)
        self._model     = genai.GenerativeModel(settings.gemini_model)
        self._genai_mod = genai

    async def chat(
        self,
        messages: list[dict[str, str]],
        system_prompt: str = "",
        temperature: float = 0.3,
        max_tokens: int = 2048,
    ) -> tuple[str, LLMUsage]:
        # Gemini uses a single string prompt or structured history
        full_prompt = ""
        if system_prompt:
            full_prompt += f"[Instructions système]\n{system_prompt}\n\n"
        for msg in messages:
            role    = msg.get("role", "user").capitalize()
            content = msg.get("content", "")
            full_prompt += f"{role}: {content}\n"

        response = await self._model.generate_content_async(
            full_prompt,
            generation_config=self._genai_mod.types.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            ),
        )
        text  = response.text or ""
        usage = LLMUsage()  # Gemini doesn't always expose token counts
        return text, usage

    async def embed(self, text: str) -> list[float]:
        result = self._genai_mod.embed_content(
            model="models/text-embedding-004",
            content=text,
        )
        return result["embedding"]


# ── Factory ───────────────────────────────────────────────────────────────────

@lru_cache(maxsize=1)
def get_llm_client() -> BaseLLMClient:
    provider = settings.llm_provider
    log.info("llm_client.init", provider=provider)
    if provider == "gemini":
        return GeminiClient()
    return OpenAIClient()
