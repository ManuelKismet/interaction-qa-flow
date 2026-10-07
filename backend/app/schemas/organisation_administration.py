from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


OrganisationPermission = Literal[
    "team_create",
    "team_membership",
    "review",
    "answer_approval",
]


class OrganisationPermissionCreate(BaseModel):
    user_id: UUID
    permission: OrganisationPermission
    scope_type: Literal["organisation", "department", "team"]
    scope_id: UUID | None = None


class OrganisationPermissionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organisation_id: UUID
    user_id: UUID
    permission: str
    scope_type: str
    scope_id: UUID | None
    granted_by: UUID
    created_at: datetime


class OrganisationJoinRequestCreate(BaseModel):
    request_type: Literal["team", "department"]
    target_id: UUID
    reason: str | None = Field(default=None, max_length=2000)


class OrganisationJoinRequestDecision(BaseModel):
    decision: Literal["approve", "decline"]
    reviewer_note: str | None = Field(default=None, max_length=2000)


class OrganisationJoinRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    organisation_id: UUID
    requester_id: UUID
    request_type: str
    target_id: UUID
    status: str
    reason: str | None
    reviewed_by: UUID | None
    reviewer_note: str | None
    created_at: datetime
    reviewed_at: datetime | None


class OwnerAppointment(BaseModel):
    user_id: UUID


class OrganisationCapability(BaseModel):
    permission: str
    scope_type: str
    scope_id: UUID | None


class OrganisationProfile(BaseModel):
    organisation_id: UUID
    organisation_name: str
    user_id: UUID
    role: str
    primary_department: str | None
    teams: list[str]
    is_owner: bool
    permissions: list[str]
    permission_scopes: list[OrganisationCapability]
    assignment_managers: list[str]


class OrganisationOwnerSummary(BaseModel):
    user_id: UUID
    display_name: str
    email: str
    active: bool
