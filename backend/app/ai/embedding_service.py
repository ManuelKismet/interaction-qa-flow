import hashlib

from sqlalchemy import case, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider
from app.models.answer import Answer, AnswerStatus
from app.models.question import Question
from app.models.question_embedding import QuestionEmbedding
from app.repositories.question_embedding import QuestionEmbeddingRepository


def question_embedding_text(
    title: str,
    body: str | None,
    answer: str | None = None,
) -> str:
    parts = [title.strip()]
    if body and body.strip():
        parts.append(body.strip())
    if answer and answer.strip():
        parts.append(answer.strip())
    return "\n\n".join(parts)


def embedding_source_hash(text: str, model_name: str) -> str:
    return hashlib.sha256(f"{model_name}\0{text}".encode("utf-8")).hexdigest()


class EmbeddingService:
    def __init__(self, session: AsyncSession, provider: EmbeddingProvider) -> None:
        self.session = session
        self.provider = provider
        self.embeddings = QuestionEmbeddingRepository(session)

    async def sync_question(self, question: Question) -> bool:
        answer_body = await self.session.scalar(
            select(Answer.body)
            .where(
                Answer.question_id == question.id,
                Answer.organisation_id == question.organisation_id,
                Answer.archived_at.is_(None),
                (Answer.status == AnswerStatus.VERIFIED)
                | (Answer.id == question.accepted_answer_id),
            )
            .order_by(
                case((Answer.id == question.accepted_answer_id, 0), else_=1),
                Answer.created_at.desc(),
                Answer.id.desc(),
            )
            .limit(1)
        )
        text = question_embedding_text(question.title, question.body, answer_body)
        source_hash = embedding_source_hash(text, self.provider.model_name)
        existing = await self.embeddings.get_for_question(
            question.id,
            question.organisation_id,
        )
        if (
            existing
            and existing.source_hash == source_hash
            and existing.embedding_model == self.provider.model_name
        ):
            return False

        if existing is not None:
            await self.session.delete(existing)
            await self.session.commit()

        vector = await self.provider.embed_text(text)
        if len(vector) != self.provider.dimensions:
            raise ValueError("Embedding dimensions do not match provider configuration")
        await self.embeddings.add(
            QuestionEmbedding(
                organisation_id=question.organisation_id,
                question_id=question.id,
                embedding=vector,
                embedding_model=self.provider.model_name,
                source_hash=source_hash,
            )
        )
        await self.session.commit()
        return True