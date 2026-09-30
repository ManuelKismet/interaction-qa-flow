from uuid import UUID

from pydantic import BaseModel, Field

from app.models.team import TeamStatus
from app.schemas.common import EntityResponse, ORMModel
from app.schemas.department import DepartmentSummary
from app.schemas.user import UserSummary


class TeamCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    department_id: UUID | None = None
    status: TeamStatus = TeamStatus.ACTIVE


class TeamUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    department_id: UUID | None = None
    status: TeamStatus | None = None


class TeamSummary(ORMModel):
    id: UUID
    name: str
    department_id: UUID | None


class TeamResponse(EntityResponse):
    organisation_id: UUID
    name: str
    description: str | None
    status: TeamStatus
    department: DepartmentSummary | None


class TeamMemberCreate(BaseModel):
    user_id: UUID


class TeamMembershipResponse(EntityResponse):
    organisation_id: UUID
    team_id: UUID
    user: UserSummary