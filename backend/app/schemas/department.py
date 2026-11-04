from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.common import EntityResponse, ORMModel


class DepartmentCreate(BaseModel):
    organisation_id: UUID | None = None
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None


class DepartmentResponse(EntityResponse):
    organisation_id: UUID
    name: str
    description: str | None


class DepartmentSummary(ORMModel):
    id: UUID
    name: str