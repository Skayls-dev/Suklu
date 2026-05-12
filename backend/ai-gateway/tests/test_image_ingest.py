from __future__ import annotations

import io
import sys
from types import SimpleNamespace

import pytest
from PIL import Image
from pypdf import PdfWriter

from app.ingest.image_captioner import caption_image
from app.ingest.image_extractor import extract_images_from_pdf

image_captioner_module = sys.modules[caption_image.__module__]
image_extractor_module = sys.modules[extract_images_from_pdf.__module__]


def _png_bytes(width: int, height: int) -> bytes:
    image = Image.new("RGB", (width, height), color=(120, 120, 120))
    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def test_extract_images_from_pdf_empty() -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=595, height=842)
    payload = io.BytesIO()
    writer.write(payload)

    extracted = extract_images_from_pdf(payload.getvalue(), "doc-empty")
    assert extracted == []


def test_extract_images_filters_small(monkeypatch: pytest.MonkeyPatch) -> None:
    small_image_bytes = _png_bytes(30, 30)

    class _FakeStream:
        def get_data(self) -> bytes:
            return small_image_bytes

    class _FakePage:
        images = [{"stream": _FakeStream()}]

        @staticmethod
        def extract_text() -> str:
            return "Petit schéma"

    class _FakePdf:
        pages = [_FakePage()]

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    monkeypatch.setattr(image_extractor_module.pdfplumber, "open", lambda *_args, **_kwargs: _FakePdf())

    extracted = extract_images_from_pdf(b"dummy", "doc-small")
    assert extracted == []


@pytest.mark.asyncio
async def test_caption_image_openai(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(image_captioner_module.settings, "llm_provider", "openai")
    monkeypatch.setattr(image_captioner_module.settings, "openai_api_key", "test-key")

    class _FakeOpenAIClient:
        def __init__(self, api_key: str) -> None:
            _ = api_key
            self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

        @staticmethod
        async def _create(**_kwargs):
            return SimpleNamespace(
                choices=[SimpleNamespace(message=SimpleNamespace(content="Un schéma montrant les forces."))]
            )

    monkeypatch.setattr(image_captioner_module, "AsyncOpenAI", _FakeOpenAIClient)

    result = await caption_image(
        image_bytes=_png_bytes(120, 120),
        mime_type="image/png",
        page_text_context="Contexte de physique",
        subject="Physique",
        grade_level="Terminale",
        llm=SimpleNamespace(),
    )
    assert "schéma" in result.lower()


@pytest.mark.asyncio
async def test_caption_image_fallback_on_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(image_captioner_module.settings, "llm_provider", "openai")
    monkeypatch.setattr(image_captioner_module.settings, "openai_api_key", "test-key")

    warnings: list[tuple[str, dict]] = []

    def _warning(event: str, **kwargs):
        warnings.append((event, kwargs))

    class _FailingOpenAIClient:
        def __init__(self, api_key: str) -> None:
            _ = api_key
            self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

        @staticmethod
        async def _create(**_kwargs):
            raise RuntimeError("vision failed")

    monkeypatch.setattr(image_captioner_module.log, "warning", _warning)
    monkeypatch.setattr(image_captioner_module, "AsyncOpenAI", _FailingOpenAIClient)

    result = await caption_image(
        image_bytes=_png_bytes(120, 120),
        mime_type="image/png",
        page_text_context="Contexte de maths",
        subject="Mathématiques",
        grade_level="3e",
        llm=SimpleNamespace(),
    )

    assert result.startswith("[Schéma de Mathématiques")
    assert any(event == "image_captioner.failed" for event, _ in warnings)
