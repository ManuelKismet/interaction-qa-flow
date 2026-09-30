from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.duplicate_suggestion import DuplicateSuggestionStatus
from app.schemas.common import EntityResponse, ORMModel


class CanonicalQuestionSummary(ORMModel):
    id: UUID
    title: str


class QuestionAliasSummary(ORMModel):
    id: UUID
    title: str
    created_at: datetime


class MergeQuestionsRequest(BaseModel):
    duplicate_question_ids: list[UUID] = Field(min_length=1, max_length=100)
    canonical_answer_id: UUID | None = None
    reason: str = Field(min_length=1, max_length=4000)


class MergeQuestionsResponse(BaseModel):
    canonical_question_id: UUID
    merged_question_ids: list[UUID]
    canonical_answer_id: UUID | None


class DuplicateSuggestionCreate(BaseModel):
    suggested_canonical_question_id: UUID
    reason: str | None = Field(default=None, max_length=4000)


class DuplicateSuggestionDecision(BaseModel):
    reason: str | None = Field(default=None, max_length=4000)
    canonical_answer_id: UUID | None = None


class UnmergeQuestionRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=4000)


class DuplicateSuggestionResponse(EntityResponse):
    organisation_id: UUID
    question_id: UUID
    question_title: str
    suggested_canonical_question_id: UUID
    suggested_canonical_title: str
    submitted_by: UUID
    reason: str | None
    status: DuplicateSuggestionStatus
    reviewed_by: UUID | None
    reviewed_at: datetime | None