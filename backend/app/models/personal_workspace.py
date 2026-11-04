from pgvector.sqlalchemy import Vector
from sqlalchemy import CheckConstraint, Index, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class PersonalWorkspaceItem(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "personal_workspace_items"
    __table_args__ = (
        UniqueConstraint(
            "firebase_uid",
            "source_key",
            name="uq_personal_workspace_item_source",
        ),
        CheckConstraint(
            "kind IN ('knowledge', 'interact_session', 'template')",
            name="ck_personal_workspace_item_kind",
        ),
        CheckConstraint("revision > 0", name="ck_personal_workspace_item_revision"),
        Index("ix_personal_workspace_items_firebase_uid", "firebase_uid"),
    )

    firebase_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    source_key: Mapped[str] = mapped_column(String(128), nullable=False)
    kind: Mapped[str] = mapped_column(String(30), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    data: Mapped[dict] = mapped_column(JSON, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    knowledge_embedding: Mapped[list[float] | None] = mapped_column(Vector(1536))
    embedding_model: Mapped[str | None] = mapped_column(String(255))
    embedding_source_hash: Mapped[str | None] = mapped_column(String(64))
