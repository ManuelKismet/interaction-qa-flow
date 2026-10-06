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


def _require_nonempty_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        raise ValueError(f"{field} must be non-empty text.")
    return value


def _object_list(value: Any, field: str, *, optional: bool = False) -> list[dict]:
    if value is None and optional:
        return []
    if not isinstance(value, list) or any(not isinstance(item, dict) for item in value):
        raise ValueError(f"{field} must be a list of objects.")
    return value


def validate_personal_workspace_data(
    kind: str,
    data: dict[str, Any],
    *,
    source_key: str | None = None,
) -> None:
    item_id = _require_nonempty_string(data.get("id"), "Item ID")
    if source_key is not None:
        prefix, separator, source_id = source_key.partition(":")
        expected_prefixes = {
            "knowledge": {"knowledge"},
            "interact_session": {"session", "interact_session"},
            "template": {"template"},
        }
        if (
            not separator
            or prefix not in expected_prefixes.get(kind, set())
            or source_id != item_id
        ):
            raise ValueError("The source key must match the item's stable ID.")

    if kind == "knowledge":
        return

    participants: set[str] = set()
    slots: set[str] = set()
    if kind == "interact_session":
        for participant in _object_list(data.get("participants"), "Participants"):
            participant_id = _require_nonempty_string(
                participant.get("id"), "Participant ID"
            )
            if participant_id in participants:
                raise ValueError("Participant IDs must be unique.")
            participants.add(participant_id)
            if participant.get("name") is not None and not isinstance(
                participant["name"], str
            ):
                raise ValueError("Participant names must be text.")
    elif kind == "template":
        _require_nonempty_string(data.get("name"), "Template name")
        for slot in _object_list(
            data.get("participant_slots"), "Participant slots", optional=True
        ):
            slot_id = _require_nonempty_string(slot.get("id"), "Participant slot ID")
            _require_nonempty_string(slot.get("label"), "Participant slot label")
            if slot_id in slots:
                raise ValueError("Participant slot IDs must be unique.")
            slots.add(slot_id)
    else:
        raise ValueError("Unsupported personal workspace item kind.")

    question_ids: set[str] = set()

    def validate_questions(value: Any, field: str) -> None:
        for question in _object_list(value, field, optional=field != "Questions"):
            question_id = _require_nonempty_string(question.get("id"), "Question ID")
            _require_nonempty_string(question.get("text"), "Question text")
            if question_id in question_ids:
                raise ValueError("Question IDs must be unique within an item.")
            question_ids.add(question_id)

            scope = question.get("scope")
            if scope is not None and (
                not isinstance(scope, str) or scope not in {"shared", "participant"}
            ):
                raise ValueError("Question scope must be shared or participant.")
            target_field = (
                "target_participant_slot"
                if kind == "template"
                else "target_participant_id"
            )
            target = question.get(target_field)
            if target is not None:
                target = _require_nonempty_string(target, target_field)
                allowed_targets = slots if kind == "template" else participants
                if (
                    kind == "interact_session" or allowed_targets
                ) and target not in allowed_targets:
                    raise ValueError(
                        f"{target_field} must reference an item participant."
                    )

            validate_questions(question.get("follow_ups"), "Question follow-ups")
            answers = _object_list(
                question.get("answers"), "Question answers", optional=True
            )
            for answer in answers:
                owner_field = (
                    "participant_slot" if kind == "template" else "participant_id"
                )
                owner = _require_nonempty_string(answer.get(owner_field), owner_field)
                allowed_owners = slots if kind == "template" else participants
                if (
                    kind == "interact_session" or allowed_owners
                ) and owner not in allowed_owners:
                    raise ValueError(
                        f"{owner_field} must reference an item participant."
                    )
                if answer.get("body") is not None and not isinstance(
                    answer["body"], str
                ):
                    raise ValueError("Answer bodies must be text.")
                if answer.get("branches_collapsed") is not None and not isinstance(
                    answer["branches_collapsed"], bool
                ):
                    raise ValueError("branches_collapsed must be a boolean.")
                validate_questions(
                    answer.get("follow_ups"),
                    "Answer follow-ups",
                )

    validate_questions(data.get("questions"), "Questions")


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
        validate_personal_workspace_data(
            self.kind,
            self.data,
            source_key=self.source_key,
        )
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
