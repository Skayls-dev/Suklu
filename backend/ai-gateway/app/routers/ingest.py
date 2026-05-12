"""
POST /ingest — Curriculum document ingestion pipeline.

Accepts PDF, DOCX, and standalone image files. PDFs can also contribute
embedded images that are captioned, uploaded, and indexed in Qdrant.
"""
import hashlib
import io
import uuid
from pathlib import Path
from typing import Annotated

import structlog
import tiktoken
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from google.cloud import firestore, storage
from qdrant_client.models import FieldCondition, Filter, MatchValue, PointIdsList

from app.config import settings
from app.ingest.image_captioner import caption_image
from app.ingest.image_extractor import extract_images_from_pdf
from app.ingest.image_storage import upload_image_to_storage
from app.llm.llm_client import BaseLLMClient, get_llm_client
from app.vector_db.qdrant_service import QdrantService, get_qdrant_service

log = structlog.get_logger()
router = APIRouter()

_STAFF_ROLES = {"academic_staff", "super_admin"}
_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
_DOCUMENT_EXTENSIONS = {".pdf", ".docx", ".doc"}


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
    enc = tiktoken.get_encoding("cl100k_base")
    tokens = enc.encode(text)
    chunks: list[str] = []
    start = 0
    step = max(1, chunk_size - overlap)

    while start < len(tokens):
        end = min(start + chunk_size, len(tokens))
        chunks.append(enc.decode(tokens[start:end]))
        start += step

    return chunks


def _mime_type_for_ext(ext: str) -> str:
    return {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
    }.get(ext, "application/octet-stream")


def _storage_bucket_name() -> str:
    return settings.gcs_bucket or f"{settings.gcp_project_id}.appspot.com"


@router.post("")
async def ingest_document(
    file: UploadFile = File(...),
    subject: str = Form(...),
    grade_level: str = Form(...),
    country: str = Form("Sénégal"),
    caption: str = Form(""),
    request: Request = None,  # type: ignore[assignment]
    llm: Annotated[BaseLLMClient, Depends(get_llm_client)] = None,  # type: ignore[assignment]
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)] = None,  # type: ignore[assignment]
) -> dict:
    user = _require_staff(request)

    data = await file.read()
    filename = file.filename or "document"
    ext = Path(filename).suffix.lower()
    doc_id = str(uuid.uuid4())
    text_chunk_points: list[dict] = []
    image_chunk_points: list[dict] = []
    text_chunk_count = 0

    if ext in _DOCUMENT_EXTENSIONS:
        if ext == ".pdf":
            text = _extract_text_pdf(data)
        else:
            text = _extract_text_docx(data)

        if text.strip():
            chunks = _chunk_text(text, settings.chunk_size, settings.chunk_overlap)
            text_chunk_count = len(chunks)

            for i, chunk in enumerate(chunks):
                vector = await llm.embed(chunk)
                text_chunk_points.append(
                    {
                        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{doc_id}-text-{i}")),
                        "vector": vector,
                        "payload": {
                            "text": chunk,
                            "chunk_type": "text",
                            "doc_id": doc_id,
                            "subject": subject,
                            "grade_level": grade_level,
                            "country": country,
                            "chunk_index": i,
                            "source_file": filename,
                        },
                    }
                )

        if ext == ".pdf":
            try:
                extracted_images = extract_images_from_pdf(data, doc_id)
                log.info("ingest.images_found", count=len(extracted_images), doc_id=doc_id)

                for img in extracted_images:
                    img_id = f"{doc_id}-img-p{img.page_number}-{img.image_index}"

                    image_url = await upload_image_to_storage(
                        img.image_bytes,
                        img.mime_type,
                        doc_id,
                        img_id,
                    )

                    caption_text = await caption_image(
                        img.image_bytes,
                        img.mime_type,
                        img.page_text_context,
                        subject,
                        grade_level,
                        llm,
                    )

                    if not caption_text:
                        continue

                    caption_with_context = f"[SCHÉMA page {img.page_number}] {caption_text}"
                    vector = await llm.embed(caption_with_context)
                    image_chunk_points.append(
                        {
                            "id": str(uuid.uuid5(uuid.NAMESPACE_URL, img_id)),
                            "vector": vector,
                            "payload": {
                                "text": caption_with_context,
                                "chunk_type": "image",
                                "image_url": image_url,
                                "doc_id": doc_id,
                                "subject": subject,
                                "grade_level": grade_level,
                                "country": country,
                                "page_number": img.page_number,
                                "source_file": filename,
                            },
                        }
                    )

                if image_chunk_points:
                    log.info("ingest.images_indexed", count=len(image_chunk_points), doc_id=doc_id)
            except Exception as exc:  # noqa: BLE001
                log.warning("ingest.image_processing_failed", error=str(exc), doc_id=doc_id)

    elif ext in _IMAGE_EXTENSIONS:
        mime_type = file.content_type or _mime_type_for_ext(ext)
        manual_caption = caption.strip()
        if not manual_caption:
            manual_caption = await caption_image(
                data,
                mime_type,
                "",
                subject,
                grade_level,
                llm,
            )

        image_url = await upload_image_to_storage(data, mime_type, doc_id, f"{doc_id}-main")
        caption_with_context = manual_caption.strip()
        vector = await llm.embed(caption_with_context)
        image_chunk_points.append(
            {
                "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{doc_id}-main")),
                "vector": vector,
                "payload": {
                    "text": caption_with_context,
                    "chunk_type": "image",
                    "image_url": image_url,
                    "doc_id": doc_id,
                    "subject": subject,
                    "grade_level": grade_level,
                    "country": country,
                    "page_number": 1,
                    "source_file": filename,
                },
            }
        )
        log.info("ingest.image_standalone_indexed", doc_id=doc_id, filename=filename)

    else:
        raise HTTPException(status_code=415, detail="Seuls les fichiers PDF, DOCX et images sont acceptés")

    if not text_chunk_points and not image_chunk_points:
        raise HTTPException(status_code=400, detail="Document vide ou illisible")

    points = text_chunk_points + image_chunk_points
    await qdrant.ensure_collection(vector_size=len(points[0]["vector"]))
    await qdrant.upsert(points)

    try:
        db = firestore.AsyncClient()
        await db.collection("rag_documents").document(doc_id).set(
            {
                "id": doc_id,
                "filename": filename,
                "subject": subject,
                "grade_level": grade_level,
                "country": country,
                "textChunkCount": text_chunk_count,
                "imageChunkCount": len(image_chunk_points),
                "chunkCount": len(points),
                "uploadedBy": user.get("uid"),
                "createdAt": firestore.SERVER_TIMESTAMP,
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )
    except Exception as exc:  # noqa: BLE001
        log.warning("ingest.firestore_write_failed", error=str(exc))

    log.info(
        "ingest.complete",
        doc_id=doc_id,
        text_chunks=text_chunk_count,
        image_chunks=len(image_chunk_points),
        subject=subject,
    )
    return {
        "docId": doc_id,
        "chunksIngested": text_chunk_count,
        "imagesIndexed": len(image_chunk_points),
    }


@router.get("/images")
async def list_doc_images(
    doc_id: str,
    request: Request,
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)],
) -> dict:
    _require_staff(request)

    scroll_filter = Filter(
        must=[
            FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
            FieldCondition(key="chunk_type", match=MatchValue(value="image")),
        ]
    )

    points, _ = await qdrant._client.scroll(  # noqa: SLF001
        collection_name=settings.qdrant_collection,
        scroll_filter=scroll_filter,
        limit=100,
        with_payload=True,
        with_vectors=False,
    )

    images = []
    for point in points:
        payload = point.payload or {}
        images.append(
            {
                "id": str(point.id),
                "image_url": payload.get("image_url", ""),
                "caption": payload.get("text", ""),
                "page_number": payload.get("page_number", 0),
            }
        )

    return {"images": images}


@router.delete("/{doc_id}")
async def delete_document(
    doc_id: str,
    request: Request,
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)],
) -> dict:
    _require_staff(request)

    errors: list[str] = []

    try:
        await qdrant._client.delete(  # noqa: SLF001
            collection_name=settings.qdrant_collection,
            points_selector=Filter(must=[FieldCondition(key="doc_id", match=MatchValue(value=doc_id))]),
        )
    except Exception as exc:  # noqa: BLE001
        errors.append(f"qdrant: {exc}")
        log.warning("ingest.delete_qdrant_failed", doc_id=doc_id, error=str(exc))

    try:
        client = storage.Client(project=settings.gcp_project_id)
        bucket = client.bucket(_storage_bucket_name())
        for blob in bucket.list_blobs(prefix=f"rag_images/{doc_id}/"):
            blob.delete()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"storage: {exc}")
        log.warning("ingest.delete_storage_failed", doc_id=doc_id, error=str(exc))

    try:
        db = firestore.AsyncClient()
        await db.collection("rag_documents").document(doc_id).delete()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"firestore: {exc}")
        log.warning("ingest.delete_firestore_failed", doc_id=doc_id, error=str(exc))

    return {"deleted": True, "doc_id": doc_id, "errors": errors}


@router.delete("/images/{doc_id}/{image_id}")
async def delete_document_image(
    doc_id: str,
    image_id: str,
    request: Request,
    qdrant: Annotated[QdrantService, Depends(get_qdrant_service)],
) -> dict:
    _require_staff(request)

    errors: list[str] = []
    image_url = ""

    try:
        points, _ = await qdrant._client.scroll(  # noqa: SLF001
            collection_name=settings.qdrant_collection,
            scroll_filter=Filter(
                must=[
                    FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
                    FieldCondition(key="chunk_type", match=MatchValue(value="image")),
                ]
            ),
            limit=100,
            with_payload=True,
            with_vectors=False,
        )
        for point in points:
            if str(point.id) == image_id:
                image_url = (point.payload or {}).get("image_url", "")
                break

        await qdrant._client.delete(  # noqa: SLF001
            collection_name=settings.qdrant_collection,
            points_selector=PointIdsList(points=[image_id]),
        )
    except Exception as exc:  # noqa: BLE001
        errors.append(f"qdrant: {exc}")
        log.warning("ingest.delete_image_qdrant_failed", doc_id=doc_id, image_id=image_id, error=str(exc))

    try:
        if image_url:
            client = storage.Client(project=settings.gcp_project_id)
            bucket = client.bucket(_storage_bucket_name())
            blob_name = image_url.split(bucket.name + "/", 1)[-1] if bucket.name in image_url else None
            if blob_name:
                blob = bucket.blob(blob_name)
                if blob.exists():
                    blob.delete()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"storage: {exc}")
        log.warning("ingest.delete_image_storage_failed", doc_id=doc_id, image_id=image_id, error=str(exc))

    return {"deleted": True, "doc_id": doc_id, "image_id": image_id, "errors": errors}
