"""Suggestion Bank persistence. Audience and original contributions are immutable."""

import uuid
from datetime import datetime
from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class BankSuggestion(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "bank_suggestions"
    __table_args__ = (
        CheckConstraint(
            "(organisation_id IS NOT NULL AND group_id IS NULL AND scope_type IN ('organisation','department','team')) OR (organisation_id IS NULL AND group_id IS NOT NULL AND scope_type = 'group')",
            name="ck_bank_audience",
        ),
        CheckConstraint(
            "(scope_type = 'department' AND department_id IS NOT NULL AND team_id IS NULL) OR (scope_type = 'team' AND team_id IS NOT NULL) OR (scope_type IN ('organisation','group') AND department_id IS NULL AND team_id IS NULL)",
            name="ck_bank_scope",
        ),
        CheckConstraint(
            "status IN ('submitted','under_review','needs_information','planned','in_progress','implemented','not_proceeding')",
            name="ck_bank_status",
        ),
        CheckConstraint(
            "kind IN ('suggestion','proposal','feedback','etiquette')",
            name="ck_bank_kind",
        ),
        CheckConstraint("revision > 0", name="ck_bank_revision"),
        ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_bank_department_org",
        ),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_bank_team_org",
        ),
        UniqueConstraint("author_key", "client_key", name="uq_bank_submission_retry"),
        Index(
            "ix_bank_org_scope",
            "organisation_id",
            "scope_type",
            "department_id",
            "team_id",
            "created_at",
        ),
    )
    organisation_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), index=True
    )
    group_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("guest_groups.id", ondelete="CASCADE"), index=True
    )
    department_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    team_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    scope_type: Mapped[str] = mapped_column(String(20))
    kind: Mapped[str] = mapped_column(String(20))
    title: Mapped[str] = mapped_column(String(500))
    problem: Mapped[str] = mapped_column(Text)
    proposal: Mapped[str] = mapped_column(Text)
    benefit: Mapped[str] = mapped_column(Text)
    author_key: Mapped[str] = mapped_column(String(140))
    author_name: Mapped[str] = mapped_column(String(255))
    client_key: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(30), default="submitted")
    revision: Mapped[int] = mapped_column(Integer, default=1)
    owner_key: Mapped[str | None] = mapped_column(String(140))
    owner_name: Mapped[str | None] = mapped_column(String(255))
    review_due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    practice: Mapped[str | None] = mapped_column(Text)
    knowledge_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    interact_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    linked_to_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("bank_suggestions.id", ondelete="SET NULL")
    )


class BankActivity(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "bank_activities"
    __table_args__ = (
        UniqueConstraint(
            "suggestion_id", "actor_key", "client_key", name="uq_bank_action_retry"
        ),
    )
    suggestion_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("bank_suggestions.id", ondelete="CASCADE"), index=True
    )
    actor_key: Mapped[str] = mapped_column(String(140))
    actor_name: Mapped[str] = mapped_column(String(255))
    client_key: Mapped[str] = mapped_column(String(64))
    request_hash: Mapped[str | None] = mapped_column(String(64))
    action: Mapped[str] = mapped_column(String(30))
    text: Mapped[str] = mapped_column(Text)
    revision: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class BankFollower(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "bank_followers"
    __table_args__ = (
        UniqueConstraint("suggestion_id", "actor_key", name="uq_bank_follower"),
    )
    suggestion_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("bank_suggestions.id", ondelete="CASCADE"), index=True
    )
    actor_key: Mapped[str] = mapped_column(String(140))
    seen_revision: Mapped[int] = mapped_column(Integer, default=0)
