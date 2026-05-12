from contextlib import asynccontextmanager

import firebase_admin
import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.middleware.safety_filter import SafetyFilterMiddleware
from app.routers import chat, diagnostic, ingest, quiz, session_summary

log = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ────────────────────────────────────────────────────────────────
    log.info("ai_gateway.startup", llm_provider=settings.llm_provider)

    # Initialize Firebase Admin SDK once (uses service account or ADC on GCP)
    if not firebase_admin._apps:  # noqa: SLF001 — intentional singleton guard
        cred_path = settings.firebase_service_account_path
        if cred_path and cred_path.exists():
            cred = firebase_admin.credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred, {"projectId": settings.gcp_project_id})
        else:
            # On Cloud Run, Application Default Credentials are used automatically
            firebase_admin.initialize_app(options={"projectId": settings.gcp_project_id})

    yield

    # ── Shutdown ───────────────────────────────────────────────────────────────
    log.info("ai_gateway.shutdown")


app = FastAPI(
    title="Suklu AI Gateway",
    description="AI tutoring backend — RAG chat, diagnostics, quiz generation",
    version="1.0.0",
    lifespan=lifespan,
    # Disable automatic /docs in production to reduce attack surface
    docs_url="/docs" if settings.debug else None,
    redoc_url=None,
)

# CORS — allow all origins in dev (Flutter web ports vary dynamically)
# In production, use specific origins with allow_credentials=True
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,  # Can't use True with "*"
    allow_methods=["*"],
    allow_headers=["*"],
)

# Content safety runs on every request body before route handlers
app.add_middleware(SafetyFilterMiddleware)

app.include_router(diagnostic.router, prefix="/diagnostic", tags=["diagnostic"])
app.include_router(chat.router,       prefix="/chat",       tags=["chat"])
app.include_router(ingest.router,     prefix="/ingest",     tags=["ingest"])
app.include_router(quiz.router,       prefix="/quiz",       tags=["quiz"])
app.include_router(session_summary.router, prefix="/session-summary", tags=["session-summary"])


@app.get("/health", include_in_schema=False)
async def health():
    return {"status": "healthy", "llm_provider": settings.llm_provider}


__all__ = ["app"]
