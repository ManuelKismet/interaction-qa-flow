import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class ChallengeType(str, enum.Enum):
    OUTDATED = "outdated"
    INCORRECT = "incorrect"
    UNCLEAR = "unclear"
    INCOMPLETE = "incomplete"
    SUGGEST_UPDATE = "suggest_update"


class ChallengeStatus(str, enum.Enum):
    OPEN = "open"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"


class AnswerChallenge(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "answer_challenges"

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organisations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    answer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("answers.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    submitted_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    type: Mapped[ChallengeType] = mapped_column(
        Enum(
            ChallengeType,
            name="challenge_type",
            values_callable=lambda values: [item.value for item in values],
        ),
        nullable=False,
    )
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    suggested_answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ChallengeStatus] = mapped_column(
        Enum(
            ChallengeStatus,
            name="challenge_status",
            values_callable=lambda values: [item.value for item in values],
        ),
        default=ChallengeStatus.OPEN,
        index=True,
        nullable=False,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    reviewer_note: Mapped[str | None] = mapped_column(Text, nullable=True)