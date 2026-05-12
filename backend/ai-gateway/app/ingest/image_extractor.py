from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from typing import Any

import pdfplumber
import structlog
from PIL import Image, ImageFile

log = structlog.get_logger()

ImageFile.LOAD_TRUNCATED_IMAGES = True


@dataclass(slots=True)
class ExtractedImage:
    page_number: int
    image_index: int
    image_bytes: bytes
    mime_type: str
    width: int
    height: int
    page_text_context: str


def _to_png(image: Image.Image) -> tuple[bytes, str, int, int]:
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGB")

    output = BytesIO()
    image.save(output, format="PNG")
    width, height = image.size
    return output.getvalue(), "image/png", width, height


def _extract_image_bytes(image_obj: dict[str, Any]) -> bytes:
    stream = image_obj.get("stream")
    if stream is not None:
        try:
            return stream.get_data()
        except Exception:
            pass

    raw = image_obj.get("srcstream")
    if isinstance(raw, (bytes, bytearray)):
        return bytes(raw)
    return b""


def extract_images_from_pdf(pdf_bytes: bytes, doc_id: str) -> list[ExtractedImage]:
    extracted: list[ExtractedImage] = []

    with pdfplumber.open(BytesIO(pdf_bytes)) as pdf:
        for page_index, page in enumerate(pdf.pages, start=1):
            try:
                page_text_context = (page.extract_text() or "")[:500]
                page_images = getattr(page, "images", []) or []
                page_count = 0

                for image_index, image_obj in enumerate(page_images):
                    image_bytes = _extract_image_bytes(image_obj)
                    if not image_bytes:
                        continue

                    try:
                        with Image.open(BytesIO(image_bytes)) as img:
                            width, height = img.size
                            if width < 50 or height < 50:
                                continue

                            png_bytes, mime_type, width, height = _to_png(img)
                            extracted.append(
                                ExtractedImage(
                                    page_number=page_index,
                                    image_index=image_index,
                                    image_bytes=png_bytes,
                                    mime_type=mime_type,
                                    width=width,
                                    height=height,
                                    page_text_context=page_text_context,
                                )
                            )
                            page_count += 1
                    except Exception as exc:  # noqa: BLE001
                        log.warning(
                            "ingest.image_decode_failed",
                            doc_id=doc_id,
                            page_number=page_index,
                            image_index=image_index,
                            error=str(exc),
                        )

                log.info(
                    "ingest.page_images_extracted",
                    doc_id=doc_id,
                    page_number=page_index,
                    count=page_count,
                )
            except Exception as exc:  # noqa: BLE001
                log.warning(
                    "ingest.page_image_extraction_failed",
                    doc_id=doc_id,
                    page_number=page_index,
                    error=str(exc),
                )

    return extracted