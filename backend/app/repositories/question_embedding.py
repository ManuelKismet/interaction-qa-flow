from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.question_embedding import QuestionEmbedding


class QuestionEmbeddingRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_for_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> QuestionEmbedding | None:
        result = await self.session.execute(
            select(QuestionEmbedding).where(
                QuestionEmbedding.question_id == question_id,
                QuestionEmbedding.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def add(self, embedding: QuestionEmbedding) -> QuestionEmbedding:
        self.session.add(embedding)
        await self.session.flush()
        return embedding