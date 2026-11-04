from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.common import EntityResponse
from app.schemas.user import UserSummary


class CommentCreate(BaseModel):
    organisation_id: UUID | None = None
    author_id: UUID | None = None
    answer_id: UUID | None = None
    body: str = Field(min_length=1)


class CommentUpdate(BaseModel):
    organisation_id: UUID | None = None
    user_id: UUID | None = None
    body: str = Field(min_length=1)


class CommentResponse(EntityResponse):
    organisation_id: UUID
    question_id: UUID
    answer_id: UUID | None
    author_id: UUID
    body: str
    author: UserSummary