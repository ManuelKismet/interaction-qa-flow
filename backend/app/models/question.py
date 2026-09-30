import enum
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, ForeignKeyConstraint, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class QuestionStatus(str, enum.Enum):
    OPEN = "open"
    ANSWERED = "answered"
    RESOLVED = "resolved"
    UNDER_REVIEW = "under_review"
    ARCHIVED = "archived"


class QuestionVisibility(str, enum.Enum):
    ORGANISATION = "organisation"
    DEPARTMENT = "department"
    PRIVATE = "private"


class Question(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "questions"
    __table_args__ = (
        CheckConstraint(
            "canonical_question_id IS NULL OR canonical_question_id <> id",
            name="ck_questions_canonical_not_self",
        ),
        Index("ix_questions_canonical_question_id", "canonical_question_id"),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_questions_team_organisation",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organisations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    department_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("departments.id", ondelete="SET NULL"),
        nullable=True,
    )
    team_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        index=True,
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[QuestionStatus] = mapped_column(
        Enum(
            QuestionStatus,
            name="question_status",
            values_callable=lambda values: [item.value for item in values],
        ),
        default=QuestionStatus.OPEN,
        nullable=False,
    )
    visibility: Mapped[QuestionVisibility] = mapped_column(
        Enum(
            QuestionVisibility,
            name="question_visibility",
            values_callable=lambda values: [item.value for item in values],
        ),
        default=QuestionVisibility.ORGANISATION,
        nullable=False,
    )
    canonical_question_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("questions.id", ondelete="SET NULL"),
        nullable=True,
    )
    accepted_answer_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("answers.id", ondelete="SET NULL", use_alter=True),
        index=True,
        nullable=True,
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )