from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.ai.embedding_provider import (
    DeterministicFakeEmbeddingProvider,
    EmbeddingProviderError,
)
from app.core.config import Settings
from app.models.answer import Answer, AnswerStatus
from app.models.question import Question, QuestionStatus, QuestionVisibility
from app.models.user import User
from app.schemas.search import MatchConfidence
from app.services.search import SearchService


class FailingEmbeddingProvider(DeterministicFakeEmbeddingProvider):
    async def embed_text(self, text: str) -> list[float]:
        raise EmbeddingProviderError("provider unavailable")


def candidate(
    actor: User,
    *,
    similarity: float,
    answer_status: AnswerStatus,
    resolved_at: datetime,
    review_due_at: datetime | None = None,
) -> tuple[Question, Question, Answer, None, None, float, int]:
    question_id = uuid4()
    question = Question(
        id=question_id,
        organisation_id=actor.organisation_id,
        author_id=actor.id,
        title=f"Question {question_id}",
        status=QuestionStatus.RESOLVED,
        visibility=QuestionVisibility.ORGANISATION,
        resolved_at=resolved_at,
        created_at=resolved_at - timedelta(days=1),
        updated_at=resolved_at,
    )
    answer = Answer(
        id=uuid4(),
        organisation_id=actor.organisation_id,
        question_id=question_id,
        author_id=actor.id,
        body="Accepted answer",
        status=answer_status,
        review_due_at=review_due_at,
    )
    question.accepted_answer_id = answer.id
    return question, question, answer, None, None, similarity, 0


@pytest.mark.asyncio
async def test_search_classifies_and_ranks_candidates() -> None:
    now = datetime.now(UTC)
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="search@example.test",
        display_name="Search Tester",
    )
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
        clock=lambda: now,
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.lexical_candidates = AsyncMock(return_value=[])
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=[
            candidate(
                actor,
                similarity=0.749,
                answer_status=AnswerStatus.VERIFIED,
                resolved_at=now - timedelta(days=2),
            ),
            candidate(
                actor,
                similarity=0.751,
                answer_status=AnswerStatus.COMMUNITY,
                resolved_at=now,
            ),
            candidate(
                actor,
                similarity=0.9,
                answer_status=AnswerStatus.PROPOSED,
                resolved_at=now - timedelta(days=10),
            ),
        ]
    )

    results = await service.search(
        query="How do I claim mileage?",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
    )

    assert [result.similarity for result in results] == [0.9, 0.751, 0.749]
    assert results[0].confidence == MatchConfidence.HIGH_CONFIDENCE
    assert results[1].confidence == MatchConfidence.RELATED
    assert "embedding" not in results[0].model_dump()


@pytest.mark.asyncio
async def test_search_can_include_open_question_without_answer() -> None:
    now = datetime(2026, 2, 1, tzinfo=UTC)
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="ask@example.test",
        display_name="Ask Tester",
    )
    question = Question(
        id=uuid4(),
        organisation_id=actor.organisation_id,
        author_id=actor.id,
        title="How do I correct a mileage claim?",
        status=QuestionStatus.OPEN,
        visibility=QuestionVisibility.ORGANISATION,
        created_at=now,
        updated_at=now,
    )
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
        clock=lambda: now,
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.lexical_candidates = AsyncMock(return_value=[])
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=[(question, question, None, None, None, 0.91, 0)]
    )

    results = await service.search(
        query="Correct mileage claim",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
        include_unanswered=True,
    )

    assert len(results) == 1
    assert results[0].question_status == QuestionStatus.OPEN
    assert results[0].answer_id is None
    assert results[0].accepted_answer_body is None
    service.search_repository.semantic_candidates.assert_awaited_once_with(
        organisation_id=actor.organisation_id,
        actor=actor,
        query_text="Correct mileage claim",
        query_embedding=await service.provider.embed_text("Correct mileage claim"),
        embedding_model=service.provider.model_name,
        minimum_similarity=service.settings.related_match_threshold,
        limit=50,
        include_unanswered=True,
    )


@pytest.mark.asyncio
async def test_search_ranks_fresh_verified_before_overdue_and_community() -> None:
    now = datetime(2026, 2, 1, tzinfo=UTC)
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="ranking@example.test",
        display_name="Ranking Tester",
    )
    candidates = [
        candidate(
            actor,
            similarity=0.8,
            answer_status=AnswerStatus.COMMUNITY,
            resolved_at=now,
        ),
        candidate(
            actor,
            similarity=0.8,
            answer_status=AnswerStatus.VERIFIED,
            resolved_at=now,
            review_due_at=now - timedelta(days=1),
        ),
        candidate(
            actor,
            similarity=0.8,
            answer_status=AnswerStatus.VERIFIED,
            resolved_at=now,
            review_due_at=now + timedelta(days=60),
        ),
    ]
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
        clock=lambda: now,
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.lexical_candidates = AsyncMock(return_value=[])
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=candidates
    )

    results = await service.search(
        query="Mileage policy",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
    )

    assert [result.answer_freshness_status for result in results] == [
        "current",
        "overdue",
        None,
    ]


@pytest.mark.asyncio
async def test_search_collapses_aliases_using_strongest_similarity() -> None:
    now = datetime(2026, 2, 1, tzinfo=UTC)
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="aliases@example.test",
        display_name="Alias Tester",
    )
    canonical, _, answer, department, team, _, challenge_count = candidate(
        actor,
        similarity=0.8,
        answer_status=AnswerStatus.VERIFIED,
        resolved_at=now,
        review_due_at=now + timedelta(days=60),
    )
    alias = Question(
        id=uuid4(),
        organisation_id=actor.organisation_id,
        author_id=actor.id,
        title="Where do I book holiday?",
        status=QuestionStatus.RESOLVED,
        visibility=QuestionVisibility.ORGANISATION,
        canonical_question_id=canonical.id,
        created_at=now,
        updated_at=now,
    )
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
        clock=lambda: now,
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.lexical_candidates = AsyncMock(return_value=[])
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=[
            (canonical, canonical, answer, department, team, 0.82, challenge_count),
            (alias, canonical, answer, department, team, 0.94, challenge_count),
        ]
    )

    results = await service.search(
        query="Holiday booking",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
    )

    assert len(results) == 1
    assert results[0].question_id == canonical.id
    assert results[0].similarity == 0.94
    assert results[0].matched_question_id == alias.id
    assert set(results[0].matched_question_ids) == {canonical.id, alias.id}
    assert results[0].match_source == "historical_question"


@pytest.mark.asyncio
async def test_search_fuses_branch_ranks_without_exposing_keyword_scores() -> None:
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="fusion@example.test",
        display_name="Fusion Tester",
    )
    first = candidate(
        actor,
        similarity=100.0,
        answer_status=AnswerStatus.COMMUNITY,
        resolved_at=datetime.now(UTC),
    )
    second_lexical = candidate(
        actor,
        similarity=10.0,
        answer_status=AnswerStatus.COMMUNITY,
        resolved_at=datetime.now(UTC),
    )
    keyword_only = candidate(
        actor,
        similarity=10.0,
        answer_status=AnswerStatus.COMMUNITY,
        resolved_at=datetime.now(UTC),
    )
    first_semantic = (*first[:5], 0.7, first[6])
    second_semantic = (*second_lexical[:5], 0.9, second_lexical[6])
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.lexical_candidates = AsyncMock(
        return_value=[first, second_lexical, keyword_only]
    )
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=[second_semantic, first_semantic]
    )

    results = await service.search(
        query="reset password",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
    )

    assert results[0].question_id == second_lexical[0].id
    assert results[0].match_method == "hybrid"
    keyword_result = next(
        result for result in results if result.question_id == keyword_only[0].id
    )
    assert keyword_result.match_method == "keyword"
    assert keyword_result.similarity == 0.0
    assert keyword_result.confidence == MatchConfidence.LOW_CONFIDENCE


@pytest.mark.asyncio
async def test_search_preserves_lexical_results_when_provider_fails() -> None:
    actor = User(
        id=uuid4(),
        organisation_id=uuid4(),
        email="failure@example.test",
        display_name="Failure Tester",
    )
    service = SearchService(AsyncMock(), FailingEmbeddingProvider(), Settings())
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.semantic_candidates = AsyncMock()
    lexical_hit = candidate(
        actor,
        similarity=11.0,
        answer_status=AnswerStatus.COMMUNITY,
        resolved_at=datetime.now(UTC),
    )
    service.search_repository.lexical_candidates = AsyncMock(
        return_value=[lexical_hit]
    )

    results = await service.search(
        query="Mileage claim",
        limit=5,
        organisation_id=actor.organisation_id,
        user_id=actor.id,
    )

    assert len(results) == 1
    assert results[0].similarity == 0.0
    assert results[0].confidence == MatchConfidence.LOW_CONFIDENCE
    service.search_repository.semantic_candidates.assert_not_awaited()