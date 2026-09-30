import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError

from app.ai.embedding_provider import EmbeddingProviderError, get_embedding_provider
from app.ai.embedding_service import EmbeddingService
from app.core.database import async_session_factory
from app.models.question import Question

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def backfill_question_embeddings() -> tuple[int, int, int]:
    provider = get_embedding_provider()
    created_or_updated = 0
    unchanged = 0
    failed = 0

    async with async_session_factory() as session:
        question_ids = list(await session.scalars(select(Question.id)))
        service = EmbeddingService(session, provider)
        for question_id in question_ids:
            question = await session.get(Question, question_id)
            if question is None:
                continue
            try:
                if await service.sync_question(question):
                    created_or_updated += 1
                else:
                    unchanged += 1
            except (EmbeddingProviderError, SQLAlchemyError, ValueError):
                await session.rollback()
                failed += 1
                logger.exception("Failed to embed question %s", question_id)

    return created_or_updated, unchanged, failed


async def main() -> None:
    created_or_updated, unchanged, failed = await backfill_question_embeddings()
    print(
        "Embedding backfill complete: "
        f"{created_or_updated} updated, {unchanged} unchanged, {failed} failed"
    )


if __name__ == "__main__":
    asyncio.run(main())