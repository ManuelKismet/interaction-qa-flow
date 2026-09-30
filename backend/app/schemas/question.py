from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.question import QuestionStatus, QuestionVisibility
from app.schemas.answer import AnswerDetailResponse
from app.schemas.canonical import CanonicalQuestionSummary, QuestionAliasSummary
from app.schemas.common import EntityResponse
from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary
from app.schemas.team import TeamSummary


class QuestionCreate(BaseModel):
    # TODO(auth): derive organisation_id and author_id from the authenticated identity.
    organisation_id: UUID
    author_id: UUID
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


class QuestionUpdate(BaseModel):
    # TODO(auth): derive organisation_id and user_id from the authenticated identity.
    organisation_id: UUID
    user_id: UUID
    title: str | None = Field(default=None, min_length=1, max_length=500)
    body: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    visibility: QuestionVisibility | None = None


class QuestionAction(BaseModel):
    # TODO(auth): derive organisation_id and user_id from the authenticated identity.
    organisation_id: UUID
    user_id: UUID


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