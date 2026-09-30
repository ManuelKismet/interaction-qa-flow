from datetime import datetime
from enum import StrEnum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.models.guided import (
    GuidedQuestionScope,
    GuidedQuestionSource,
    GuidedSessionStatus,
    GuidedSessionVisibility,
    GuidedTemplateStatus,
    KnowledgeProposalStatus,
)
from app.schemas.common import EntityResponse, ORMModel


class GuidedViewMode(StrEnum):
    ALL_RELEVANT = "all_relevant"
    SHARED_ONLY = "shared_only"
    PARTICIPANT_ONLY = "participant_only"


class GuidedTemplateQuestionInput(BaseModel):
    text: str = Field(min_length=1)
    scope: GuidedQuestionScope = GuidedQuestionScope.SHARED
    participant_reference: str | None = None
    order_index: int = Field(default=0, ge=0)
    parent_reference: str | None = None
    reference: str | None = None


class GuidedTemplateCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    questions: list[GuidedTemplateQuestionInput] = []


class GuidedTemplateUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None


class GuidedTemplateQuestionResponse(ORMModel):
    id: UUID
    text: str
    scope: GuidedQuestionScope
    participant_reference: str | None
    order_index: int
    parent_template_question_id: UUID | None


class GuidedTemplateVersionResponse(ORMModel):
    id: UUID
    template_id: UUID
    version_number: int
    created_by: UUID
    created_at: datetime
    questions: list[GuidedTemplateQuestionResponse] = []


class GuidedTemplateResponse(EntityResponse):
    organisation_id: UUID
    created_by: UUID
    name: str
    description: str | None
    department_id: UUID | None
    team_id: UUID | None
    status: GuidedTemplateStatus
    current_version: int
    version: GuidedTemplateVersionResponse | None = None


class GuidedTemplateVersionCreate(BaseModel):
    questions: list[GuidedTemplateQuestionInput]


class GuidedTemplateImportRequest(BaseModel):
    payload: dict[str, Any] | list[Any]


class GuidedSessionCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    owner_text: str | None = Field(default=None, max_length=255)
    context_reference: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    visibility: GuidedSessionVisibility = GuidedSessionVisibility.PRIVATE
    template_id: UUID | None = None
    template_version_id: UUID | None = None


class GuidedSessionUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    owner_text: str | None = Field(default=None, max_length=255)
    context_reference: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None
    visibility: GuidedSessionVisibility | None = None
    expected_revision: int | None = Field(default=None, ge=1)


class GuidedParticipantCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    role_label: str | None = Field(default=None, max_length=255)
    linked_user_id: UUID | None = None
    notes: str | None = None
    sort_order: int = Field(default=0, ge=0)


class GuidedParticipantUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    role_label: str | None = Field(default=None, max_length=255)
    linked_user_id: UUID | None = None
    notes: str | None = None
    sort_order: int | None = Field(default=None, ge=0)


class GuidedParticipantResponse(EntityResponse):
    organisation_id: UUID
    session_id: UUID
    name: str
    role_label: str | None
    linked_user_id: UUID | None
    notes: str | None
    sort_order: int


class GuidedQuestionCreate(BaseModel):
    text: str = Field(min_length=1)
    scope: GuidedQuestionScope
    target_participant_id: UUID | None = None
    main_order_index: int | None = Field(default=None, ge=0)
    knowledge_question_id: UUID | None = None

    @model_validator(mode="after")
    def validate_target(self):
        if self.scope == GuidedQuestionScope.PARTICIPANT and self.target_participant_id is None:
            raise ValueError("Participant questions require a target participant")
        if self.scope == GuidedQuestionScope.SHARED and self.target_participant_id is not None:
            raise ValueError("Shared questions cannot target one participant")
        return self


class GuidedFollowUpCreate(BaseModel):
    text: str = Field(min_length=1)
    branch_order_index: int | None = Field(default=None, ge=0)


class GuidedQuestionUpdate(BaseModel):
    text: str | None = Field(default=None, min_length=1)
    main_order_index: int | None = Field(default=None, ge=0)
    branch_order_index: int | None = Field(default=None, ge=0)
    knowledge_question_id: UUID | None = None


class GuidedAnswerUpsert(BaseModel):
    participant_id: UUID
    body: str = ""
    branches_collapsed: bool = False


class GuidedAnswerUpdate(BaseModel):
    body: str | None = None
    branches_collapsed: bool | None = None


class GuidedQuestionResponse(EntityResponse):
    organisation_id: UUID
    session_id: UUID
    template_question_id: UUID | None
    created_by: UUID
    text: str
    scope: GuidedQuestionScope
    target_participant_id: UUID | None
    source: GuidedQuestionSource
    main_order_index: int | None
    branch_order_index: int | None
    triggering_answer_id: UUID | None
    knowledge_question_id: UUID | None
    deleted_at: datetime | None


class GuidedAnswerResponse(EntityResponse):
    organisation_id: UUID
    session_id: UUID
    question_id: UUID
    participant_id: UUID
    answered_by_user_id: UUID | None
    body: str
    branches_collapsed: bool


class GuidedFlowQuestion(GuidedQuestionResponse):
    answers: list[GuidedAnswerResponse] = []
    follow_ups: list["GuidedFlowQuestion"] = []


class GuidedSessionSummary(EntityResponse):
    organisation_id: UUID
    created_by: UUID
    template_id: UUID | None
    template_version_id: UUID | None
    title: str
    owner_text: str | None
    context_reference: str | None
    department_id: UUID | None
    team_id: UUID | None
    visibility: GuidedSessionVisibility
    status: GuidedSessionStatus
    revision: int
    started_at: datetime | None
    completed_at: datetime | None


class GuidedSessionResponse(GuidedSessionSummary):
    participants: list[GuidedParticipantResponse] = []
    questions: list[GuidedFlowQuestion] = []
    prepared_question_count: int = 0
    follow_up_count: int = 0


class GuidedRevisionResponse(ORMModel):
    id: UUID
    session_id: UUID
    revision_number: int
    saved_by: UUID
    summary: dict[str, Any]
    created_at: datetime


class KnowledgeProposalCreate(BaseModel):
    guided_question_id: UUID
    guided_answer_id: UUID
    proposed_question_text: str | None = None
    proposed_answer_text: str | None = None
    department_id: UUID | None = None
    team_id: UUID | None = None


class KnowledgeProposalDecision(BaseModel):
    action: str = Field(pattern="^(accept|reject|link)$")
    existing_question_id: UUID | None = None


class KnowledgeProposalResponse(EntityResponse):
    organisation_id: UUID
    guided_session_id: UUID
    guided_question_id: UUID
    guided_answer_id: UUID
    proposed_by: UUID
    proposed_question_text: str
    proposed_answer_text: str
    department_id: UUID | None
    team_id: UUID | None
    status: KnowledgeProposalStatus
    reviewed_by: UUID | None
    reviewed_at: datetime | None
    created_question_id: UUID | None
    linked_question_id: UUID | None


class LegacyImportRequest(BaseModel):
    payload: dict[str, Any] | list[Any]


class LegacyImportResponse(BaseModel):
    session: GuidedSessionResponse
    warnings: list[str] = []


class GuidedKnowledgeSearch(BaseModel):
    query: str | None = None
    limit: int = Field(default=5, ge=1, le=20)