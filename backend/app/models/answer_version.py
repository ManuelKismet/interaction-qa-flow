import uuid

from sqlalchemy import Enum, ForeignKey, Integer, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.answer import AnswerStatus
from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class AnswerVersion(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "answer_versions"
    __table_args__ = (
        UniqueConstraint(
            "question_id",
            "version_number",
            name="uq_answer_versions_question_number",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organisations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    question_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("questions.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    answer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("answers.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    version_number: Mapped[int] = mapped_column(Integer, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status_snapshot: Mapped[AnswerStatus] = mapped_column(
        Enum(
            AnswerStatus,
            name="answer_status",
            values_callable=lambda values: [item.value for item in values],
        ),
        nullable=False,
    )
    changed_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    change_reason: Mapped[str | None] = mapped_column(Text, nullable=True)