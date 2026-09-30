import pytest
from sqlalchemy import select

from app.ai.embedding_provider import DeterministicFakeEmbeddingProvider
from app.ai.embedding_service import (
    EmbeddingService,
    embedding_source_hash,
    question_embedding_text,
)
from app.models.organisation import Organisation
from app.models.question import Question
from app.models.question_embedding import QuestionEmbedding
from app.models.user import User


class CountingEmbeddingProvider(DeterministicFakeEmbeddingProvider):
    def __init__(self) -> None:
        super().__init__()
        self.calls = 0

    async def embed_text(self, text: str) -> list[float]:
        self.calls += 1
        return await super().embed_text(text)


def test_embedding_input_contains_only_question_content() -> None:
    text = question_embedding_text("  Mileage claims  ", "  How do I submit one? ")

    assert text == "Mileage claims\n\nHow do I submit one?"
    assert embedding_source_hash(text, "model-a") == embedding_source_hash(
        text,
        "model-a",
    )
    assert embedding_source_hash(text, "model-a") != embedding_source_hash(
        text,
        "model-b",
    )


@pytest.mark.asyncio
async def test_embedding_sync_skips_unchanged_and_updates_changed_question(
    app_client,
) -> None:
    _, session_factory = app_client
    provider = CountingEmbeddingProvider()
    async with session_factory() as session:
        organisation = Organisation(name="Example", slug="embedding-example")
        session.add(organisation)
        await session.flush()
        author = User(
            organisation_id=organisation.id,
            email="embedding@example.test",
            display_name="Embedding Tester",
        )
        session.add(author)
        await session.flush()
        question = Question(
            organisation_id=organisation.id,
            author_id=author.id,
            title="How do I claim mileage?",
            body="Travel expense details",
        )
        session.add(question)
        await session.commit()

        service = EmbeddingService(session, provider)
        assert await service.sync_question(question) is True
        assert await service.sync_question(question) is False
        assert provider.calls == 1

        question.body = "Updated travel expense details"
        await session.commit()
        assert await service.sync_question(question) is True
        assert provider.calls == 2

        stored = (
            await session.execute(
                select(QuestionEmbedding).where(
                    QuestionEmbedding.question_id == question.id
                )
            )
        ).scalar_one()
        assert stored.embedding_model == provider.model_name
        assert len(stored.embedding) == provider.dimensions