from pydantic import BaseModel, Field

from app.schemas.common import EntityResponse


class OrganisationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    slug: str = Field(pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$", max_length=100)


class OrganisationResponse(EntityResponse):
    name: str
    slug: str