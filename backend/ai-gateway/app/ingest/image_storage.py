from __future__ import annotations

import asyncio

import structlog
from google.cloud import storage

from app.config import settings

log = structlog.get_logger()


def _resolve_bucket_name() -> str:
    if settings.gcs_bucket:
        return settings.gcs_bucket
    return f"{settings.gcp_project_id}.appspot.com"


async def upload_image_to_storage(
    image_bytes: bytes,
    mime_type: str,
    doc_id: str,
    image_id: str,
) -> str:
    bucket_name = _resolve_bucket_name()
    ext = "png" if mime_type == "image/png" else "jpg"
    blob_name = f"rag_images/{doc_id}/{image_id}.{ext}"

    def _upload() -> str:
        client = storage.Client(project=settings.gcp_project_id)
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.upload_from_string(image_bytes, content_type=mime_type)
        blob.cache_control = "public, max-age=31536000"
        blob.make_public()
        return blob.public_url

    try:
        return await asyncio.to_thread(_upload)
    except Exception as exc:  # noqa: BLE001
        log.warning(
            "ingest.image_upload_failed",
            error=str(exc),
            doc_id=doc_id,
            image_id=image_id,
            bucket=bucket_name,
        )
        return ""