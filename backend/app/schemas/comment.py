from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.common import EntityResponse
from app.schemas.user import UserSummary


class CommentCreate(BaseModel):
    # TODO(auth): derive organisation_id and author_id from the authenticated identity.
    organisation_id: UUID
    author_id: UUID
    answer_id: UUID | None = None
    body: str = Field(min_length=1)


class CommentUpdate(BaseModel):
    # TODO(auth): derive organisation_id and user_id from the authenticated identity.
    organisation_id: UUID
    user_id: UUID
    body: str = Field(min_length=1)


class CommentResponse(EntityResponse):
    organisation_id: UUID
    question_id: UUID
    answer_id: UUID | None
    author_id: UUID
    body: str
    author: UserSummary