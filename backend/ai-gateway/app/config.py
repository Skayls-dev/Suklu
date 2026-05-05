from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── LLM ───────────────────────────────────────────────────────────────────
    llm_provider: Literal["openai", "gemini"] = "openai"

    openai_api_key:        str  = ""
    openai_model:          str  = "gpt-4o-mini"
    openai_embedding_model: str = "text-embedding-3-small"

    gemini_api_key: str = ""
    gemini_model:   str = "gemini-1.5-flash"

    # ── Vector DB ─────────────────────────────────────────────────────────────
    qdrant_url:        str = "http://localhost:6333"
    qdrant_api_key:    str = ""
    qdrant_collection: str = "suklu_curriculum"

    # ── Firebase ──────────────────────────────────────────────────────────────
    firebase_service_account_path: Path | None = None
    gcp_project_id: str = "suklu-prod"

    # ── Safety ────────────────────────────────────────────────────────────────
    content_moderation_enabled: bool = True
    min_user_age: int = 8

    # ── Embedding chunking ────────────────────────────────────────────────────
    chunk_size:    int = 512
    chunk_overlap: int = 64

    # ── CORS ──────────────────────────────────────────────────────────────────
    # In production, replace with the actual Firebase Hosting domain
    # In dev, allow all origins (Flutter web ports vary dynamically)
    cors_origins: list[str] = ["*"]

    # ── Dev ───────────────────────────────────────────────────────────────────
    debug: bool = False
    # Skip Firebase token verification in local dev (no service account needed)
    skip_auth: bool = False


settings = Settings()
