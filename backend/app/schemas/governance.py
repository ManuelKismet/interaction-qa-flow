from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.answer import AnswerStatus
from app.models.answer_challenge import ChallengeStatus, ChallengeType
from app.models.duplicate_suggestion import DuplicateSuggestionStatus
from app.schemas.common import EntityResponse
from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary


class FreshnessStatus(StrEnum):
    CURRENT = "current"
    REVIEW_DUE_SOON = "review_due_soon"
    OVERDUE = "overdue"
    CHALLENGED = "challenged"
    SUPERSEDED = "superseded"


class VerifyAnswerRequest(BaseModel):
    make_accepted: bool = True
    review_days: int | None = Field(default=None, ge=1, le=3650)


class ReviewAnswerRequest(BaseModel):
    review_days: int | None = Field(default=None, ge=1, le=3650)


class ChallengeCreate(BaseModel):
    type: ChallengeType
    reason: str = Field(min_length=1, max_length=4000)
    suggested_answer: str | None = Field(default=None, max_length=20000)


class ChallengeDecision(BaseModel):
    reviewer_note: str | None = Field(default=None, max_length=4000)
    replacement_body: str | None = Field(default=None, max_length=20000)
    review_days: int | None = Field(default=None, ge=1, le=3650)


class AnswerChallengeResponse(EntityResponse):
    organisation_id: UUID
    answer_id: UUID
    submitted_by: UUID
    type: ChallengeType
    reason: str
    suggested_answer: str | None
    status: ChallengeStatus
    reviewed_by: UUID | None
    reviewed_at: datetime | None
    reviewer_note: str | None


class AnswerVersionResponse(BaseModel):
    id: UUID
    answer_id: UUID
    version_number: int
    body: str
    status_snapshot: AnswerStatus
    changed_by: UserSummary
    change_reason: str | None
    created_at: datetime


class DepartmentAnswerOwnerCreate(BaseModel):
    user_id: UUID


class DepartmentAnswerOwnerResponse(EntityResponse):
    organisation_id: UUID
    department: DepartmentSummary
    user: UserSummary


class ReviewQueueType(StrEnum):
    CHALLENGE = "challenge"
    REVIEW_DUE = "review_due"
    REVIEW_DUE_SOON = "review_due_soon"
    NEEDS_VERIFICATION = "needs_verification"
    DUPLICATE_SUGGESTION = "duplicate_suggestion"


class ReviewQueueItem(BaseModel):
    type: ReviewQueueType
    question_id: UUID
    question_title: str
    answer_id: UUID | None = None
    department: DepartmentSummary | None
    relevant_at: datetime | None
    challenge_id: UUID | None = None
    challenge_type: ChallengeType | None = None
    challenge_status: ChallengeStatus | None = None
    duplicate_suggestion_id: UUID | None = None
    duplicate_suggestion_status: DuplicateSuggestionStatus | None = None
    suggested_canonical_question_id: UUID | None = None
    suggested_canonical_title: str | None = None


class AuditEventResponse(BaseModel):
    id: UUID
    actor_id: UUID
    action: str
    entity_type: str
    entity_id: UUID
    metadata: dict | None
    created_at: datetime