import json
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


def _validate_content(value: dict[str, Any]) -> dict[str, Any]:
    try:
        encoded = json.dumps(value, ensure_ascii=False, allow_nan=False)
    except (TypeError, ValueError, RecursionError):
        raise ValueError("Personal workspace content must be valid JSON.") from None
    if len(encoded.encode("utf-8")) > 250_000:
        raise ValueError("A personal workspace item exceeds the size limit.")
    return value


class PersonalWorkspaceSchema(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class PersonalWorkspaceItemInput(PersonalWorkspaceSchema):
    kind: Literal["knowledge", "interact_session", "template"]
    source_key: str = Field(
        min_length=1,
        max_length=128,
        pattern=r"^[A-Za-z0-9._:-]+$",
    )
    title: str = Field(min_length=1, max_length=500)
    data: dict[str, Any]

    @field_validator("data")
    @classmethod
    def validate_data(cls, value: dict[str, Any]) -> dict[str, Any]:
        return _validate_content(value)

    @model_validator(mode="after")
    def validate_kind_content(self) -> "PersonalWorkspaceItemInput":
        if self.kind == "knowledge":
            if not isinstance(self.data.get("id"), str):
                raise ValueError("Knowledge items require a stable local item ID.")
        elif self.kind == "interact_session":
            if not isinstance(self.data.get("participants"), list) or not isinstance(
                self.data.get("questions"), list
            ):
                raise ValueError("Interact sessions require participants and questions.")
        elif self.kind == "template" and not isinstance(
            self.data.get("questions"), list
        ):
            raise ValueError("Interact templates require a questions list.")
        return self


class PersonalWorkspaceImport(PersonalWorkspaceSchema):
    items: list[PersonalWorkspaceItemInput] = Field(min_length=1, max_length=50)

    @model_validator(mode="after")
    def validate_batch_size(self) -> "PersonalWorkspaceImport":
        if len({item.source_key for item in self.items}) != len(self.items):
            raise ValueError("An import cannot contain duplicate source items.")
        total_bytes = sum(
            len(json.dumps(item.data, ensure_ascii=False).encode("utf-8"))
            for item in self.items
        )
        if total_bytes > 1_000_000:
            raise ValueError("The selected import exceeds the size limit.")
        return self


class PersonalWorkspaceItemUpdate(PersonalWorkspaceSchema):
    expected_revision: int = Field(ge=1)
    title: str = Field(min_length=1, max_length=500)
    data: dict[str, Any]

    @field_validator("data")
    @classmethod
    def validate_data(cls, value: dict[str, Any]) -> dict[str, Any]:
        return _validate_content(value)


class PersonalWorkspaceItemResult(PersonalWorkspaceSchema):
    id: UUID
    kind: Literal["knowledge", "interact_session", "template"]
    source_key: str
    title: str
    data: dict[str, Any]
    revision: int
    created_at: str
    updated_at: str


class PersonalWorkspaceImportResult(PersonalWorkspaceSchema):
    items: list[PersonalWorkspaceItemResult]
    created: list[bool]
