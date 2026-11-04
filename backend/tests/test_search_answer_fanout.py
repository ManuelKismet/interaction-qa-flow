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
        second_answers = []
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
        second_answers.append(
            Answer(
                organisation_id=organisation.id,
                question_id=second.id,
                author_id=user.id,
                body="Unaccepted policy answer",
                status=AnswerStatus.COMMUNITY,
            )
        )
        accepted_answer = Answer(
            organisation_id=organisation.id,
            question_id=second.id,
            author_id=user.id,
            body="Accepted policy answer",
            status=AnswerStatus.COMMUNITY,
        )
        second_answers.append(accepted_answer)
        first_accepted_answer = Answer(
            organisation_id=organisation.id,
            question_id=first.id,
            author_id=user.id,
            body="Accepted but unverified answer",
            status=AnswerStatus.COMMUNITY,
        )
        verified_answer = Answer(
            organisation_id=organisation.id,
            question_id=first.id,
            author_id=user.id,
            body="Verified answer",
            status=AnswerStatus.VERIFIED,
        )
        session.add_all(
            [*second_answers, first_accepted_answer, verified_answer]
        )
        await session.flush()
        second.accepted_answer_id = accepted_answer.id
        first.accepted_answer_id = first_accepted_answer.id
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
        results_by_id = {result.question_id: result for result in results}
        assert results_by_id[first.id].answer_id == verified_answer.id
        assert results_by_id[second.id].answer_id == accepted_answer.id


@pytest.mark.asyncio
async def test_alias_fanout_does_not_hide_distinct_canonical_match(app_client) -> None:
    _, session_factory = app_client
    async with session_factory() as session:
        organisation = Organisation(
            name="Alias fanout",
            slug="alias-fanout",
        )
        session.add(organisation)
        await session.flush()
        user = User(
            organisation_id=organisation.id,
            email="alias-fanout@example.invalid",
            display_name="Alias Synthetic",
        )
        session.add(user)
        await session.flush()
        canonical = Question(
            organisation_id=organisation.id,
            author_id=user.id,
            title="Canonical support article",
            status=QuestionStatus.ANSWERED,
        )
        other = Question(
            organisation_id=organisation.id,
            author_id=user.id,
            title="password rotation policy",
            status=QuestionStatus.ANSWERED,
        )
        session.add_all([canonical, other])
        await session.flush()
        aliases = [
            Question(
                organisation_id=organisation.id,
                author_id=user.id,
                title=f"password alias {index}",
                status=QuestionStatus.ANSWERED,
                canonical_question_id=canonical.id,
            )
            for index in range(60)
        ]
        session.add_all(aliases)
        session.add_all(
            [
                Answer(
                    organisation_id=organisation.id,
                    question_id=canonical.id,
                    author_id=user.id,
                    body="Canonical answer",
                    status=AnswerStatus.COMMUNITY,
                ),
                Answer(
                    organisation_id=organisation.id,
                    question_id=other.id,
                    author_id=user.id,
                    body="Policy answer",
                    status=AnswerStatus.COMMUNITY,
                ),
            ]
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

        assert {result.question_id for result in results} == {
            canonical.id,
            other.id,
        }
