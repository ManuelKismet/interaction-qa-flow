from datetime import datetime
from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator


class BankInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class BankScope(BankInput):
    scope_type: Literal["organisation", "department", "team", "group"]
    scope_id: UUID


class BankCreate(BankScope):
    client_key: str = Field(min_length=1, max_length=64)
    kind: Literal["suggestion", "proposal", "feedback", "etiquette"] = "suggestion"
    title: str = Field(min_length=1, max_length=500)
    problem: str = Field(min_length=1, max_length=10000)
    proposal: str = Field(min_length=1, max_length=10000)
    benefit: str = Field(default="", max_length=5000)


class BankAction(BankInput):
    client_key: str = Field(min_length=1, max_length=64)
    expected_revision: int = Field(ge=1)
    action: Literal[
        "comment",
        "support",
        "respond",
        "status",
        "assign",
        "link_duplicate",
        "unlink_duplicate",
        "escalate",
        "adopt_practice",
        "revise_practice",
        "withdraw_practice",
        "link_knowledge",
        "start_interact",
    ]
    text: str = Field(default="", max_length=10000)
    status: (
        Literal[
            "submitted",
            "under_review",
            "needs_information",
            "planned",
            "in_progress",
            "implemented",
            "not_proceeding",
        ]
        | None
    ) = None
    target_id: UUID | None = None
    target_scope: BankScope | None = None
    confirm_visibility: bool = False
    review_due_at: datetime | None = None

    @field_validator("review_due_at")
    @classmethod
    def aware_date(cls, value):
        if value is not None and value.tzinfo is None:
            raise ValueError("Include a timezone for the review date")
        return value
