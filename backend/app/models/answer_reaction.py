import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UUIDPrimaryKeyMixin


class ReactionType(str, enum.Enum):
    HELPFUL = "helpful"
    NOT_HELPFUL = "not_helpful"


class AnswerReaction(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "answer_reactions"
    __table_args__ = (
        UniqueConstraint("answer_id", "user_id", name="uq_answer_reaction_user"),
    )

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
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    reaction: Mapped[ReactionType] = mapped_column(
        Enum(
            ReactionType,
            name="reaction_type",
            values_callable=lambda values: [item.value for item in values],
        ),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )