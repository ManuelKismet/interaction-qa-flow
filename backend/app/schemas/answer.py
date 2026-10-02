from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.answer import AnswerStatus
from app.models.answer_reaction import ReactionType
from app.schemas.common import EntityResponse
from app.schemas.governance import FreshnessStatus
from app.schemas.user import UserSummary


class AnswerCreate(BaseModel):
    organisation_id: UUID | None = None
    author_id: UUID | None = None
    body: str = Field(min_length=1)


class AnswerResponse(EntityResponse):
    organisation_id: UUID
    question_id: UUID
    author_id: UUID
    body: str
    status: AnswerStatus
    verified_by: UUID | None
    verified_at: datetime | None
    review_due_at: datetime | None
    last_reviewed_at: datetime | None
    last_reviewed_by: UUID | None
    protected_at: datetime | None


class AnswerDetailResponse(AnswerResponse):
    author: UserSummary
    verified_by_user: UserSummary | None
    helpful_count: int
    not_helpful_count: int
    is_accepted: bool
    freshness_status: FreshnessStatus | None
    challenge_count: int
    has_open_challenge: bool


class AnswerUpdate(BaseModel):
    organisation_id: UUID | None = None
    user_id: UUID | None = None
    body: str = Field(min_length=1)
    reason: str | None = Field(default=None, max_length=4000)


class AnswerRestoreRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=4000)


class ReactionCreate(BaseModel):
    organisation_id: UUID | None = None
    user_id: UUID | None = None
    reaction: ReactionType


class ReactionResponse(BaseModel):
    answer_id: UUID
    reaction: ReactionType
    helpful_count: int
    not_helpful_count: int