from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.user import UserRole


class OrganisationMemberCreate(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    role: UserRole = UserRole.EMPLOYEE
    department_id: UUID | None = None

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        email = value.strip()
        if "@" not in email:
            raise ValueError("Enter a valid email address")
        return email


class OrganisationMemberUpdate(BaseModel):
    role: UserRole | None = None
    department_id: UUID | None = Field(default=None)


class OrganisationMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    display_name: str
    role: UserRole
    status: str
    department_id: UUID | None
    department_name: str | None
