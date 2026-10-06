from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as postgres_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider, get_embedding_provider
from app.ai.private_knowledge_embedding import (
    knowledge_match,
    private_knowledge_text,
    sync_private_knowledge_embedding,
)
from app.ai.embedding_service import embedding_source_hash
from app.ai.embedding_provider import EmbeddingProviderError
from app.core.config import get_settings
from app.models.personal_workspace import PersonalWorkspaceItem
from app.schemas.personal_workspace import (
    PersonalWorkspaceItemInput,
    validate_personal_workspace_data,
)

logger = logging.getLogger(__name__)


def _item_result(item: PersonalWorkspaceItem) -> dict[str, Any]:
    return {
        "id": item.id,
        "kind": item.kind,
        "source_key": item.source_key,
        "title": item.title,
        "data": item.data,
        "revision": item.revision,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


class PersonalWorkspaceService:
    def __init__(
        self,
        session: AsyncSession,
        provider: EmbeddingProvider | None = None,
    ) -> None:
        self.session = session
        self._provider_explicit = provider is not None
        try:
            self.provider = provider or get_embedding_provider()
        except EmbeddingProviderError:
            logger.exception("Personal Knowledge embeddings are unavailable")
            self.provider = None

    async def list_items(self, firebase_uid: str) -> list[dict[str, Any]]:
        result = await self.session.scalars(
            select(PersonalWorkspaceItem)
            .where(PersonalWorkspaceItem.firebase_uid == firebase_uid)
            .order_by(PersonalWorkspaceItem.created_at, PersonalWorkspaceItem.id)
        )
        return [_item_result(item) for item in result]

    async def import_items(
        self,
        firebase_uid: str,
        items: list[PersonalWorkspaceItemInput],
    ) -> dict[str, Any]:
        bind = self.session.get_bind()
        insert = {
            "sqlite": sqlite_insert,
            "postgresql": postgres_insert,
        }.get(bind.dialect.name)
        if insert is None:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Personal workspace storage is unavailable.",
            )

        stored_by_key: dict[str, dict[str, Any]] = {}
        created_by_key: dict[str, bool] = {}
        for payload in sorted(items, key=lambda item: item.source_key):
            statement = (
                insert(PersonalWorkspaceItem)
                .values(
                    firebase_uid=firebase_uid,
                    source_key=payload.source_key,
                    kind=payload.kind,
                    title=payload.title,
                    data=payload.data,
                    revision=1,
                )
                .on_conflict_do_nothing(
                    index_elements=[
                        PersonalWorkspaceItem.firebase_uid,
                        PersonalWorkspaceItem.source_key,
                    ]
                )
                .returning(PersonalWorkspaceItem)
            )
            item = (await self.session.scalars(statement)).one_or_none()
            was_created = item is not None
            if item is None:
                item = await self.session.scalar(
                    select(PersonalWorkspaceItem).where(
                        PersonalWorkspaceItem.firebase_uid == firebase_uid,
                        PersonalWorkspaceItem.source_key == payload.source_key,
                    )
                )
            if item is None:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="The personal import could not be confirmed. Retry safely.",
                )
            stored_by_key[payload.source_key] = _item_result(item)
            created_by_key[payload.source_key] = was_created
        await self.session.commit()
        for payload in items:
            if payload.kind == "knowledge" and created_by_key[payload.source_key]:
                item = await self.session.scalar(
                    select(PersonalWorkspaceItem).where(
                        PersonalWorkspaceItem.firebase_uid == firebase_uid,
                        PersonalWorkspaceItem.source_key == payload.source_key,
                    )
                )
                if item is not None:
                    await sync_private_knowledge_embedding(
                        self.session, item, provider=self.provider
                    )
        return {
            "items": [stored_by_key[item.source_key] for item in items],
            "created": [created_by_key[item.source_key] for item in items],
        }

    async def update_item(
        self,
        firebase_uid: str,
        item_id: UUID,
        *,
        expected_revision: int,
        title: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        item = await self.session.scalar(
            select(PersonalWorkspaceItem)
            .where(
                PersonalWorkspaceItem.id == item_id,
                PersonalWorkspaceItem.firebase_uid == firebase_uid,
            )
            .with_for_update()
        )
        if item is None:
            raise HTTPException(status_code=404, detail="Personal item not found.")
        if item.revision != expected_revision:
            if (
                item.revision == expected_revision + 1
                and item.title == title
                and item.data == data
            ):
                return _item_result(item)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This personal item changed elsewhere. Reload it and retry.",
            )
        try:
            validate_personal_workspace_data(
                item.kind,
                data,
                source_key=item.source_key,
            )
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=str(error),
            ) from None
        item.title = title
        item.data = data
        item.revision += 1
        await self.session.commit()
        await self.session.refresh(item)
        if item.kind == "knowledge":
            await sync_private_knowledge_embedding(
                self.session, item, provider=self.provider
            )
            await self.session.refresh(item)
        return _item_result(item)

    async def search_knowledge(
        self, firebase_uid: str, query: str, *, limit: int = 25
    ) -> dict[str, Any]:
        if not query.strip():
            return {"results": [], "partial": False}
        items = list(
            await self.session.scalars(
                select(PersonalWorkspaceItem)
                .where(
                    PersonalWorkspaceItem.firebase_uid == firebase_uid,
                    PersonalWorkspaceItem.kind == "knowledge",
                )
                .order_by(PersonalWorkspaceItem.id)
            )
        )
        provider = self.provider
        fake_embeddings = (
            provider is None
            or provider.model_name.startswith("deterministic-fake-")
        )
        semantic_available = self._provider_explicit or bool(
            get_settings().embedding_api_key
        )
        if not fake_embeddings and semantic_available:
            assert provider is not None
        fresh_ids = {
            item.id
            for item in items
            if provider is not None
            and item.embedding_model == provider.model_name
            and item.knowledge_embedding is not None
            and item.embedding_source_hash
            == embedding_source_hash(
                private_knowledge_text(item.title, item.data), provider.model_name
            )
        }

        scores: dict[str, tuple[float, str, float, str | None, str | None]] = {}
        semantic_truncated = False
        for item in items:
            lexical_score, matched_in, snippet = knowledge_match(
                query, item.title, item.data
            )
            if lexical_score:
                scores[str(item.id)] = (
                    lexical_score,
                    "keyword",
                    0.0,
                    matched_in,
                    snippet,
                )

        if not fake_embeddings and semantic_available and fresh_ids:
            assert provider is not None
            try:
                query_embedding = await provider.embed_text(query.strip())
                if len(query_embedding) != provider.dimensions:
                    raise ValueError("Embedding dimensions do not match provider")
                distance = PersonalWorkspaceItem.knowledge_embedding.cosine_distance(
                    query_embedding
                )
                semantic_rows = list(await self.session.execute(
                    select(PersonalWorkspaceItem, (1 - distance).label("similarity"))
                    .where(
                        PersonalWorkspaceItem.firebase_uid == firebase_uid,
                        PersonalWorkspaceItem.kind == "knowledge",
                        PersonalWorkspaceItem.id.in_(fresh_ids),
                        PersonalWorkspaceItem.embedding_model == provider.model_name,
                        PersonalWorkspaceItem.knowledge_embedding.is_not(None),
                    )
                    .order_by(distance)
                    .limit(limit + 1)
                ))
                semantic_truncated = len(semantic_rows) > limit
                threshold = get_settings().related_match_threshold
                for item, similarity in semantic_rows[:limit]:
                    similarity = float(similarity)
                    if similarity < threshold:
                        continue
                    current = scores.get(str(item.id))
                    relevance = max(
                        current[0] if current else 0.0,
                        similarity,
                    )
                    scores[str(item.id)] = (
                        relevance,
                        "hybrid" if current else "semantic",
                        similarity,
                        current[3] if current else None,
                        current[4] if current else None,
                    )
            except Exception:
                logger.exception(
                    "Personal Knowledge semantic search failed for an authorized query"
                )
                semantic_truncated = False

        item_by_id = {str(item.id): item for item in items}
        ranked = sorted(scores, key=lambda key: scores[key][0], reverse=True)[:limit]
        return {
            "results": [
                {
                    **_item_result(item_by_id[item_id]),
                    "source_id": item_by_id[item_id].data.get("id", item_id),
                    "match_method": scores[item_id][1],
                    "similarity": scores[item_id][2],
                    "relevance_score": scores[item_id][0],
                    "matched_in": scores[item_id][3],
                    "snippet": scores[item_id][4],
                }
                for item_id in ranked
            ],
            "partial": len(scores) > limit or semantic_truncated,
        }

    async def delete_item(
        self,
        firebase_uid: str,
        item_id: UUID,
        *,
        expected_revision: int,
    ) -> None:
        item = await self.session.scalar(
            select(PersonalWorkspaceItem)
            .where(
                PersonalWorkspaceItem.id == item_id,
                PersonalWorkspaceItem.firebase_uid == firebase_uid,
            )
            .with_for_update()
        )
        if item is None:
            return
        if item.revision != expected_revision:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This personal item changed elsewhere. Reload it and retry.",
            )
        await self.session.delete(item)
        await self.session.commit()
