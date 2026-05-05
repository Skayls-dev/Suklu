"""
POST /ingest — Curriculum document ingestion pipeline.

Accepts PDF or DOCX files, chunks them, generates embeddings, and upserts
to Qdrant. Only accessible by academic_staff and super_admin roles.

Flow:
1. Verify caller is staff (checked by safety middleware via token claim).
2. Extract text from uploaded file.
3. Chunk the text with configurable overlap.
4. Embed each chunk via the LLM client.
5. Upsert points to Qdrant with metadata (subject, grade_level, doc_id).
6. Create a /rag_documents Firestore record.
"""
import hashlib
import io
import uuid
from pathlib import Path
from typing import Annotated

import structlog
import tiktoken
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from google.cloud import firestore

from app.config import settings
from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log    = structlog.get_logger()
router = APIRouter()

_STAFF_ROLES = {"academic_staff", "super_admin"}


def _require_staff(request: Request) -> dict:
    user = request.state.user
    if user.get("role") not in _STAFF_ROLES:
        raise HTTPException(status_code=403, detail="Réservé au personnel académique")
    return user


def _extract_text_pdf(data: bytes) -> str:
    from pypdf import PdfReader
    reader = PdfReader(io.BytesIO(data))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def _extract_text_docx(data: bytes) -> str:
    from docx import Document
    doc = Document(io.BytesIO(data))
    return "\n".join(para.text for para in doc.paragraphs)


def _chunk_text(text: str, chunk_size: int, overlap: int) -> list[str]:
    enc    = tiktoken.get_encoding("cl100k_base")
    tokens = enc.encode(text)
    chunks = []
    start  = 0
    while start < len(tokens):
        end = min(start + chunk_size, len(tokens))
        chunks.append(enc.decode(tokens[start:end]))
        start += chunk_size - overlap
    return chunks


@router.post("")
async def ingest_document(
    file:        UploadFile = File(...),
    subject:     str        = Form(...),
    grade_level: str        = Form(...),
    country:     str        = Form("Sénégal"),
    request:     Request    = None,  # type: ignore[assignment]
    llm:         Annotated[BaseLLMClient, Depends(get_llm_client)] = None,  # type: ignore[assignment]
    qdrant:      Annotated[QdrantService, Depends(get_qdrant_service)] = None,  # type: ignore[assignment]
) -> dict:
    user = _require_staff(request)

    # ── Extract text ──────────────────────────────────────────────────────────
    data     = await file.read()
    filename = file.filename or "document"
    ext      = Path(filename).suffix.lower()

    if ext == ".pdf":
        text = _extract_text_pdf(data)
    elif ext in (".docx", ".doc"):
        text = _extract_text_docx(data)
    else:
        raise HTTPException(status_code=415, detail="Seuls les fichiers PDF et DOCX sont acceptés")

    if not text.strip():
        raise HTTPException(status_code=400, detail="Document vide ou illisible")

    # ── Chunk + embed ─────────────────────────────────────────────────────────
    chunks   = _chunk_text(text, settings.chunk_size, settings.chunk_overlap)
    doc_id   = str(uuid.uuid4())
    points   = []

    for i, chunk in enumerate(chunks):
        vector = await llm.embed(chunk)
        points.append({
            "id":      str(uuid.uuid5(uuid.NAMESPACE_URL, f"{doc_id}-{i}")),
            "vector":  vector,
            "payload": {
                "text":        chunk,
                "doc_id":      doc_id,
                "subject":     subject,
                "grade_level": grade_level,
                "country":     country,
                "chunk_index": i,
                "source_file": filename,
            },
        })

    await qdrant.ensure_collection(vector_size=len(points[0]["vector"]))
    await qdrant.upsert(points)

    # ── Firestore record ──────────────────────────────────────────────────────
    try:
        db = firestore.AsyncClient()
        await db.collection("rag_documents").document(doc_id).set({
            "id":          doc_id,
            "filename":    filename,
            "subject":     subject,
            "grade_level": grade_level,
            "country":     country,
            "chunkCount":  len(chunks),
            "uploadedBy":  user.get("uid"),
            "createdAt":   firestore.SERVER_TIMESTAMP,
            "sha256":      hashlib.sha256(data).hexdigest(),
        })
    except Exception as exc:
        log.warning("ingest.firestore_write_failed", error=str(exc))

    log.info("ingest.complete", doc_id=doc_id, chunks=len(chunks), subject=subject)
    return {"docId": doc_id, "chunksIngested": len(chunks)}
