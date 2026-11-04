from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class GuestSchema(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class GuestGroupCreate(GuestSchema):
    name: str = Field(min_length=1, max_length=100)
    display_name: str = Field(min_length=1, max_length=80)


class GuestInvitationCreate(GuestSchema):
    role: Literal["editor", "contributor", "viewer"] = "contributor"
    expires_in_hours: int = Field(default=24, ge=1, le=168)


class GuestInvitationToken(GuestSchema):
    token: str = Field(min_length=40, max_length=100)


class GuestJoinRequest(GuestInvitationToken):
    display_name: str = Field(min_length=1, max_length=80)


class GuestMemberRoleUpdate(GuestSchema):
    role: Literal["editor", "contributor", "viewer"]


class GuestGroupEntryCreate(GuestSchema):
    kind: Literal["knowledge", "interact_session"]
    title: str = Field(min_length=1, max_length=500)
    data: dict
    client_import_key: str | None = Field(default=None, min_length=1, max_length=64)
    share_with_group: bool = False


class GuestGroupEntryUpdate(GuestSchema):
    expected_revision: int = Field(ge=1)
    title: str | None = Field(default=None, min_length=1, max_length=500)
    data: dict | None = None


class GuestGroupImport(GuestSchema):
    entries: list[GuestGroupEntryCreate] = Field(min_length=1, max_length=50)


class GuestGroupResponse(GuestSchema):
    id: UUID
    name: str
    role: str
    expires_at: str


class GuestMemberResponse(GuestSchema):
    id: UUID
    display_name: str
    role: str
    status: str


class GuestEntryResponse(GuestSchema):
    id: UUID
    kind: str
    title: str
    data: dict
    revision: int
    created_by_uid: str
    updated_by_uid: str
    client_import_key: str | None
