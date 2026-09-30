from collections.abc import Callable
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider, EmbeddingProviderError
from app.core.config import Settings
from app.core.exceptions import ServiceUnavailableError
from app.models.answer import AnswerStatus
from app.models.question import QuestionStatus
from app.repositories.search import SearchRepository
from app.repositories.user import UserRepository
from app.schemas.department import DepartmentSummary
from app.schemas.governance import FreshnessStatus
from app.schemas.team import TeamSummary
from app.schemas.search import MatchConfidence, MatchSource, SemanticSearchResult
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
        try:
            query_embedding = await self.provider.embed_text(query.strip())
        except EmbeddingProviderError as error:
            raise ServiceUnavailableError(
                "Semantic search is temporarily unavailable"
            ) from error

        candidates = await self.search_repository.semantic_candidates(
            organisation_id=organisation_id,
            actor=actor,
            query_text=query,
            query_embedding=query_embedding,
            embedding_model=self.provider.model_name,
            minimum_similarity=self.settings.related_match_threshold,
            limit=limit * 10,
            include_unanswered=include_unanswered,
        )
        grouped: dict[UUID, tuple] = {}
        matched_ids: dict[UUID, set[UUID]] = {}
        for candidate in candidates:
            matched_question, canonical_question, _, _, _, similarity, _ = candidate
            matched_ids.setdefault(canonical_question.id, set()).add(matched_question.id)
            current = grouped.get(canonical_question.id)
            if current is None or similarity > current[5]:
                grouped[canonical_question.id] = candidate
        results = [
            SemanticSearchResult(
                question_id=canonical_question.id,
                canonical_question_id=canonical_question.id,
                canonical_title=canonical_question.title,
                canonical_body=canonical_question.body,
                matched_question_id=matched_question.id,
                matched_question_ids=sorted(
                    matched_ids[canonical_question.id], key=str
                ),
                matched_text=matched_question.title,
                match_source=MatchSource.CANONICAL
                if matched_question.id == canonical_question.id
                else MatchSource.HISTORICAL_QUESTION,
                title=canonical_question.title,
                accepted_answer_body=answer.body if answer else None,
                department=DepartmentSummary.model_validate(department)
                if department
                else None,
                team=TeamSummary.model_validate(team) if team else None,
                similarity=round(similarity, 4),
                confidence=self._confidence(similarity),
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
            for matched_question, canonical_question, answer, department, team, similarity, challenge_count in grouped.values()
        ]
        results.sort(key=self._ranking_key)
        return results[:limit]

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