from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.question import QuestionStatus, QuestionVisibility
from app.schemas.answer import AnswerDetailResponse
from app.schemas.canonical import CanonicalQuestionSummary, QuestionAliasSummary
from app.schemas.common import EntityResponse
from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary
from app.schemas.team import TeamSummary


class QuestionCreate(BaseModel):
    organisation_id: UUID | None = None
    author_id: UUID | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    title: str = Field(min_length=1, max_length=500)
    body: str | None = None
    visibility: QuestionVisibility = QuestionVisibility.ORGANISATION


class QuestionResponse(EntityResponse):
    organisation_id: UUID
    author_id: UUID
    department_id: UUID | None
    team_id: UUID | None
    title: str
    body: str | None
    status: QuestionStatus
    visibility: QuestionVisibility
    canonical_question_id: UUID | None
    accepted_answer_id: UUID | None
    resolved_at: datetime | None
    protected_at: datetime | None
    archived_at: datetime | None
    archived_by: UUID | None
    archive_reason: str | None


class QuestionUpdate(BaseModel):
    organisation_id: UUID | None = None
    user_id: UUID | None = None
    title: str | None = Field(default=None, min_length=1, max_length=500)
    body: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    visibility: QuestionVisibility | None = None
    reason: str | None = Field(default=None, max_length=4000)


class QuestionAction(BaseModel):
    organisation_id: UUID | None = None
    user_id: UUID | None = None
    reason: str | None = Field(default=None, max_length=4000)


class ArchiveQuestionRequest(QuestionAction):
    reason: str = Field(min_length=1, max_length=4000)


class RestoreQuestionRequest(QuestionAction):
    reason: str = Field(min_length=1, max_length=4000)


class QuestionChangeRequestCreate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    body: str | None = None
    archive: bool = False
    reason: str = Field(min_length=1, max_length=4000)


class ChangeRequestDecision(StrEnum):
    APPROVE = "approve"
    REJECT = "reject"


class QuestionChangeRequestReview(BaseModel):
    decision: ChangeRequestDecision
    review_note: str | None = Field(default=None, max_length=4000)


class QuestionChangeRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    question_id: UUID
    requested_by: UUID
    proposed_title: str | None
    proposed_body: str | None
    change_title: bool
    change_body: bool
    archive_requested: bool
    reason: str
    status: str
    reviewed_by: UUID | None
    reviewed_at: datetime | None
    review_note: str | None
    created_at: datetime


class QuestionVersionResponse(BaseModel):
    id: UUID
    question_id: UUID
    version_number: int
    title: str
    body: str | None
    status_snapshot: QuestionStatus
    visibility_snapshot: QuestionVisibility
    department_id: UUID | None
    team_id: UUID | None
    changed_by: UserSummary
    change_reason: str
    created_at: datetime


class QuestionResolve(QuestionAction):
    answer_id: UUID


class QuestionListItem(QuestionResponse):
    department: DepartmentSummary | None
    team: TeamSummary | None
    answer_count: int


class QuestionDetailResponse(QuestionResponse):
    author: UserSummary
    department: DepartmentSummary | None
    team: TeamSummary | None
    accepted_answer: AnswerDetailResponse | None
    answers: list[AnswerDetailResponse]
    comment_count: int
    canonical_question: CanonicalQuestionSummary | None
    aliases: list[QuestionAliasSummary]