import hashlib

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider
from app.models.question import Question
from app.models.question_embedding import QuestionEmbedding
from app.repositories.question_embedding import QuestionEmbeddingRepository


def question_embedding_text(title: str, body: str | None) -> str:
    parts = [title.strip()]
    if body and body.strip():
        parts.append(body.strip())
    return "\n\n".join(parts)


def embedding_source_hash(text: str, model_name: str) -> str:
    return hashlib.sha256(f"{model_name}\0{text}".encode("utf-8")).hexdigest()


class EmbeddingService:
    def __init__(self, session: AsyncSession, provider: EmbeddingProvider) -> None:
        self.session = session
        self.provider = provider
        self.embeddings = QuestionEmbeddingRepository(session)

    async def sync_question(self, question: Question) -> bool:
        text = question_embedding_text(question.title, question.body)
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

        vector = await self.provider.embed_text(text)
        if len(vector) != self.provider.dimensions:
            raise ValueError("Embedding dimensions do not match provider configuration")
        if existing:
            existing.embedding = vector
            existing.embedding_model = self.provider.model_name
            existing.source_hash = source_hash
        else:
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