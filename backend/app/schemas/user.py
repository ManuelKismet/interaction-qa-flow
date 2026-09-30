from uuid import UUID

from pydantic import BaseModel, Field

from app.models.user import UserRole
from app.schemas.common import EntityResponse, ORMModel


class UserCreate(BaseModel):
    # TODO(auth): derive organisation_id from the authenticated identity.
    organisation_id: UUID
    department_id: UUID | None = None
    email: str = Field(min_length=3, max_length=320)
    display_name: str = Field(min_length=1, max_length=255)
    role: UserRole = UserRole.EMPLOYEE
    status: str = Field(default="active", min_length=1, max_length=50)


class UserResponse(EntityResponse):
    organisation_id: UUID
    department_id: UUID | None
    email: str
    display_name: str
    role: UserRole
    status: str


class UserSummary(ORMModel):
    id: UUID
    display_name: str
    role: UserRole