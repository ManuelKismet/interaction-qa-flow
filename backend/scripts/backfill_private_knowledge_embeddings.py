"""Opt-in backfill for real-provider semantic search of existing private Knowledge."""

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.ai.embedding_provider import get_embedding_provider
from app.ai.embedding_service import embedding_source_hash
from app.ai.private_knowledge_embedding import (
    private_knowledge_text,
    sync_private_knowledge_embedding,
)
from app.core.config import get_settings
from app.models.guest import GuestGroupEntry
from app.models.personal_workspace import PersonalWorkspaceItem


async def _backfill_model(session, provider, model, filters) -> int:
    indexed = 0
    last_id = None
    while True:
        statement = select(model).where(*filters)
        if last_id is not None:
            statement = statement.where(model.id > last_id)
        rows = list(
            await session.scalars(statement.order_by(model.id).limit(100))
        )
        if not rows:
            return indexed
        for item in rows:
            last_id = item.id
            current_hash = embedding_source_hash(
                private_knowledge_text(item.title, item.data), provider.model_name
            )
            if (
                item.embedding_model == provider.model_name
                and item.embedding_source_hash == current_hash
                and item.knowledge_embedding is not None
            ):
                continue
            indexed += await sync_private_knowledge_embedding(
                session, item, provider=provider
            )


async def main() -> None:
    settings = get_settings()
    provider = get_embedding_provider(settings)
    if provider.model_name.startswith("deterministic-fake-"):
        raise SystemExit("Use a real configured embedding provider for backfill.")
    engine = create_async_engine(settings.database_url)
    try:
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            personal_count = await _backfill_model(
                session,
                provider,
                PersonalWorkspaceItem,
                (PersonalWorkspaceItem.kind == "knowledge",),
            )
            group_count = await _backfill_model(
                session,
                provider,
                GuestGroupEntry,
                (GuestGroupEntry.kind == "knowledge",),
            )
        print(
            "Indexed private Knowledge records: "
            f"personal={personal_count}, groups={group_count}"
        )
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
