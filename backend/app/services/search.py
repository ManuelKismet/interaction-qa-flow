from collections.abc import Callable
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider, EmbeddingProviderError
from app.core.config import Settings
from app.models.answer import AnswerStatus
from app.models.question import QuestionStatus
from app.repositories.search import SearchRepository
from app.repositories.user import UserRepository
from app.schemas.department import DepartmentSummary
from app.schemas.governance import FreshnessStatus
from app.schemas.team import TeamSummary
from app.schemas.search import (
    MatchConfidence,
    MatchMethod,
    MatchSource,
    SemanticSearchResult,
)
from app.services.freshness import answer_freshness
from app.services.permissions import PermissionService


class SearchService:
    def __init__(
        self,
        session: AsyncSession,
        provider: EmbeddingProvider,
        settings: Settings,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.provider = provider
        self.settings = settings
        self.search_repository = SearchRepository(session)
        self.permissions = PermissionService(UserRepository(session))
        self.clock = clock or (lambda: datetime.now(UTC))

    async def search(
        self,
        *,
        query: str,
        limit: int,
        organisation_id: UUID,
        user_id: UUID,
        include_unanswered: bool = False,
    ) -> list[SemanticSearchResult]:
        actor = await self.permissions.actor(user_id, organisation_id)
        lexical_candidates = await self.search_repository.lexical_candidates(
            organisation_id=organisation_id,
            actor=actor,
            query_text=query,
            limit=limit * 10,
            include_unanswered=include_unanswered,
        )
        semantic_candidates = []
        try:
            query_embedding = await self.provider.embed_text(query.strip())
            semantic_candidates = await self.search_repository.semantic_candidates(
                organisation_id=organisation_id,
                actor=actor,
                query_text=query,
                query_embedding=query_embedding,
                embedding_model=self.provider.model_name,
                minimum_similarity=self.settings.related_match_threshold,
                limit=limit * 10,
                include_unanswered=include_unanswered,
            )
        except (EmbeddingProviderError, SQLAlchemyError):
            pass

        def collapse(candidates: list[tuple]) -> dict[UUID, tuple[tuple, set[UUID], int]]:
            collapsed: dict[UUID, tuple[tuple, set[UUID], int]] = {}
            for rank, candidate in enumerate(candidates, start=1):
                matched_question, canonical_question = candidate[:2]
                group = collapsed.get(canonical_question.id)
                if group is None:
                    collapsed[canonical_question.id] = (
                        candidate,
                        {matched_question.id},
                        rank,
                    )
                    continue
                best, matched_ids, first_rank = group
                matched_ids.add(matched_question.id)
                if candidate[5] > best[5]:
                    best = candidate
                collapsed[canonical_question.id] = (best, matched_ids, first_rank)
            dense_ranks = {
                score: rank
                for rank, score in enumerate(
                    sorted({entry[0][5] for entry in collapsed.values()}, reverse=True),
                    start=1,
                )
            }
            for canonical_id, (best, matched_ids, _) in collapsed.items():
                collapsed[canonical_id] = (
                    best,
                    matched_ids,
                    dense_ranks[best[5]],
                )
            return collapsed

        lexical_by_canonical = collapse(lexical_candidates)
        semantic_by_canonical = collapse(semantic_candidates)
        canonical_ids = lexical_by_canonical.keys() | semantic_by_canonical.keys()
        ranked_results = []
        for canonical_id in canonical_ids:
            semantic_entry = semantic_by_canonical.get(canonical_id)
            lexical_entry = lexical_by_canonical.get(canonical_id)
            candidate = (lexical_entry or semantic_entry)[0]
            (
                matched_question,
                canonical_question,
                answer,
                department,
                team,
                _candidate_score,
                challenge_count,
            ) = candidate
            semantic_similarity = semantic_entry[0][5] if semantic_entry else 0.0
            matched_ids = set()
            if lexical_entry:
                matched_ids.update(lexical_entry[1])
            if semantic_entry:
                matched_ids.update(semantic_entry[1])
            reciprocal_rank = sum(
                1 / (60 + entry[2])
                for entry in (lexical_entry, semantic_entry)
                if entry is not None
            )
            result = SemanticSearchResult(
                question_id=canonical_question.id,
                canonical_question_id=canonical_question.id,
                canonical_title=canonical_question.title,
                canonical_body=canonical_question.body,
                matched_question_id=matched_question.id,
                matched_question_ids=sorted(matched_ids, key=str),
                matched_text=matched_question.title,
                match_source=MatchSource.CANONICAL
                if matched_question.id == canonical_question.id
                else MatchSource.HISTORICAL_QUESTION,
                match_method=MatchMethod.HYBRID
                if lexical_entry and semantic_entry
                else MatchMethod.KEYWORD
                if lexical_entry
                else MatchMethod.SEMANTIC,
                title=canonical_question.title,
                accepted_answer_body=answer.body if answer else None,
                department=DepartmentSummary.model_validate(department)
                if department
                else None,
                team=TeamSummary.model_validate(team) if team else None,
                similarity=round(semantic_similarity, 4)
                if semantic_entry
                else 0.0,
                confidence=self._confidence(semantic_similarity)
                if semantic_entry
                else MatchConfidence.LOW_CONFIDENCE,
                question_status=canonical_question.status,
                answer_status=answer.status if answer else None,
                answer_verified_by=answer.verified_by if answer else None,
                answer_verified_at=answer.verified_at if answer else None,
                answer_freshness_status=(
                    answer_freshness(
                        answer,
                        has_open_challenge=challenge_count > 0,
                        now=self.clock(),
                        due_soon_days=self.settings.review_due_soon_days,
                    )
                    if answer
                    else None
                ),
                created_at=canonical_question.created_at,
                updated_at=canonical_question.updated_at,
                resolved_at=canonical_question.resolved_at,
                visibility=canonical_question.visibility,
                answer_id=answer.id if answer else None,
                challenge_count=challenge_count,
                has_open_challenge=challenge_count > 0,
            )
            ranked_results.append((result, reciprocal_rank))
        ranked_results.sort(
            key=lambda item: (-item[1], self._ranking_key(item[0]))
        )
        return [result for result, _ in ranked_results[:limit]]

    def _confidence(self, similarity: float) -> MatchConfidence:
        if similarity >= self.settings.high_match_threshold:
            return MatchConfidence.HIGH_CONFIDENCE
        if similarity >= self.settings.related_match_threshold:
            return MatchConfidence.RELATED
        return MatchConfidence.LOW_CONFIDENCE

    @staticmethod
    def _ranking_key(result: SemanticSearchResult) -> tuple:
        score_band = round(result.similarity, 2)
        if (
            result.answer_status == AnswerStatus.VERIFIED
            and result.answer_freshness_status == FreshnessStatus.CURRENT
        ):
            governance_rank = 0
        elif result.answer_status == AnswerStatus.VERIFIED:
            governance_rank = 1
        elif result.question_status == QuestionStatus.RESOLVED:
            governance_rank = 2
        elif result.answer_status is not None:
            governance_rank = 3
        else:
            governance_rank = 4
        recency = result.resolved_at or result.updated_at or datetime.min
        return (-score_band, governance_rank, -recency.timestamp())