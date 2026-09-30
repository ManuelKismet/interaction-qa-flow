from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.common import EntityResponse, ORMModel


class DepartmentCreate(BaseModel):
    # TODO(auth): derive organisation_id from the authenticated identity.
    organisation_id: UUID
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None


class DepartmentResponse(EntityResponse):
    organisation_id: UUID
    name: str
    description: str | None


class DepartmentSummary(ORMModel):
    id: UUID
    name: str