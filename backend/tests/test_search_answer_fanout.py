import pytest

from app.ai.embedding_provider import (
    DeterministicFakeEmbeddingProvider,
    EmbeddingProviderError,
)
from app.core.config import Settings
from app.models.answer import Answer, AnswerStatus
from app.models.organisation import Organisation
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.services.search import SearchService


class BrokenProvider(DeterministicFakeEmbeddingProvider):
    async def embed_text(self, text: str) -> list[float]:
        raise EmbeddingProviderError("synthetic failure")


@pytest.mark.asyncio
async def test_answer_fanout_does_not_hide_other_canonical_matches(app_client) -> None:
    _, session_factory = app_client
    async with session_factory() as session:
        organisation = Organisation(
            name="Independent fanout",
            slug="independent-fanout",
        )
        session.add(organisation)
        await session.flush()
        user = User(
            organisation_id=organisation.id,
            email="fanout@example.invalid",
            display_name="Synthetic",
        )
        session.add(user)
        await session.flush()
        first = Question(
            organisation_id=organisation.id,
            author_id=user.id,
            title="password",
            status=QuestionStatus.ANSWERED,
        )
        second = Question(
            organisation_id=organisation.id,
            author_id=user.id,
            title="password rotation policy",
            status=QuestionStatus.ANSWERED,
        )
        session.add_all([first, second])
        await session.flush()
        for index in range(60):
            session.add(
                Answer(
                    organisation_id=organisation.id,
                    question_id=first.id,
                    author_id=user.id,
                    body=f"Synthetic answer {index}",
                    status=AnswerStatus.COMMUNITY,
                )
            )
        session.add(
            Answer(
                organisation_id=organisation.id,
                question_id=second.id,
                author_id=user.id,
                body="Synthetic policy answer",
                status=AnswerStatus.COMMUNITY,
            )
        )
        await session.commit()

        results = await SearchService(
            session,
            BrokenProvider(),
            Settings(),
        ).search(
            query="password",
            limit=5,
            organisation_id=organisation.id,
            user_id=user.id,
        )

        assert {result.question_id for result in results} == {first.id, second.id}
