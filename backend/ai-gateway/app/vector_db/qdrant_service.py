"""
QdrantService — wrapper around the Qdrant vector database client.

Encapsulates collection management, upsert, and similarity search.
The collection is created at first use with 1536-dim vectors (OpenAI
text-embedding-3-small). If you switch to Gemini embeddings (768-dim),
update VECTOR_SIZE or make it configurable.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Any

import structlog
from qdrant_client import AsyncQdrantClient
from qdrant_client.models import (
    Distance,
    PointStruct,
    VectorParams,
)

from app.config import settings

log = structlog.get_logger()

# Dimension for text-embedding-3-small; update if switching embedding model
_VECTOR_SIZE_MAP = {
    "text-embedding-3-small": 1536,
    "text-embedding-3-large": 3072,
    "models/text-embedding-004": 768,  # Gemini
}


class QdrantService:
    def __init__(self) -> None:
        kwargs: dict[str, Any] = {"url": settings.qdrant_url}
        if settings.qdrant_api_key:
            kwargs["api_key"] = settings.qdrant_api_key
        self._client = AsyncQdrantClient(**kwargs)

    @staticmethod
    def _infer_vector_size(query_vector: list[float] | None = None) -> int:
        if query_vector:
            return len(query_vector)
        return _VECTOR_SIZE_MAP.get(settings.openai_embedding_model, 1536)

    async def ensure_collection(self, vector_size: int = 1536) -> None:
        """Create the collection if it doesn't exist yet."""
        collections = await self._client.get_collections()
        names = [c.name for c in collections.collections]
        if settings.qdrant_collection not in names:
            await self._client.create_collection(
                collection_name=settings.qdrant_collection,
                vectors_config=VectorParams(size=vector_size, distance=Distance.COSINE),
            )
            log.info("qdrant.collection_created", name=settings.qdrant_collection)

    async def upsert(
        self,
        points: list[dict[str, Any]],  # [{id, vector, payload}]
    ) -> None:
        structs = [
            PointStruct(id=p["id"], vector=p["vector"], payload=p.get("payload", {}))
            for p in points
        ]
        await self._client.upsert(
            collection_name=settings.qdrant_collection,
            points=structs,
        )

    async def search(
        self,
        query_vector: list[float],
        limit: int = 5,
        score_threshold: float = 0.6,
        filter_payload: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        from qdrant_client.models import Filter, FieldCondition, MatchValue

        await self.ensure_collection(vector_size=self._infer_vector_size(query_vector))

        qdrant_filter = None
        if filter_payload:
            must = [
                FieldCondition(key=k, match=MatchValue(value=v))
                for k, v in filter_payload.items()
            ]
            qdrant_filter = Filter(must=must)

        results = await self._client.search(
            collection_name=settings.qdrant_collection,
            query_vector=query_vector,
            limit=limit,
            score_threshold=score_threshold,
            query_filter=qdrant_filter,
            with_payload=True,
        )
        return [
            {"score": r.score, "payload": r.payload, "id": r.id}
            for r in results
        ]


@lru_cache(maxsize=1)
def get_qdrant_service() -> QdrantService:
    return QdrantService()
