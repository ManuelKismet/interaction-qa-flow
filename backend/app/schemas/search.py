from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.answer import AnswerStatus
from app.models.question import QuestionStatus, QuestionVisibility
from app.schemas.department import DepartmentSummary
from app.schemas.governance import FreshnessStatus
from app.schemas.team import TeamSummary


class MatchConfidence(StrEnum):
    HIGH_CONFIDENCE = "high_confidence"
    RELATED = "related"
    LOW_CONFIDENCE = "low_confidence"


class MatchSource(StrEnum):
    CANONICAL = "canonical"
    ALIAS = "alias"
    HISTORICAL_QUESTION = "historical_question"


class SemanticSearchRequest(BaseModel):
    query: str = Field(min_length=3, max_length=1000)
    limit: int = Field(default=5, ge=1, le=10)
    include_unanswered: bool = False


class SemanticSearchResult(BaseModel):
    question_id: UUID
    canonical_question_id: UUID
    canonical_title: str
    canonical_body: str | None
    matched_question_id: UUID
    matched_question_ids: list[UUID]
    matched_text: str
    match_source: MatchSource
    answer_id: UUID | None
    title: str
    accepted_answer_body: str | None
    department: DepartmentSummary | None
    team: TeamSummary | None
    similarity: float
    confidence: MatchConfidence
    question_status: QuestionStatus
    answer_status: AnswerStatus | None
    answer_verified_by: UUID | None
    answer_verified_at: datetime | None
    answer_freshness_status: FreshnessStatus | None
    challenge_count: int
    has_open_challenge: bool
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None
    visibility: QuestionVisibility