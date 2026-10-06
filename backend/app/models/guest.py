import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    Index,
    String,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class GuestGroup(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guest_groups"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    archived_by_uid: Mapped[str | None] = mapped_column(String(128))


class GuestGroupMembership(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guest_group_memberships"
    __table_args__ = (
        UniqueConstraint("group_id", "firebase_uid", name="uq_guest_membership_group_uid"),
        CheckConstraint(
            "role IN ('admin', 'editor', 'contributor', 'viewer')",
            name="ck_guest_membership_role",
        ),
        CheckConstraint(
            "status IN ('pending', 'active', 'removed')",
            name="ck_guest_membership_status",
        ),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_groups.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    firebase_uid: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    display_name: Mapped[str] = mapped_column(String(80), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    approved_by_uid: Mapped[str | None] = mapped_column(String(128))


class GuestGroupAdminTransfer(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guest_group_admin_transfers"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')",
            name="ck_guest_admin_transfer_status",
        ),
        Index(
            "uq_guest_admin_transfer_pending_group",
            "group_id",
            unique=True,
            sqlite_where=text("status = 'pending'"),
            postgresql_where=text("status = 'pending'"),
        ),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_groups.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    requested_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    target_membership_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_group_memberships.id", ondelete="CASCADE"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class GuestGroupInvitation(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guest_group_invitations"
    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_guest_invitation_token_hash"),
        CheckConstraint(
            "role IN ('editor', 'contributor', 'viewer')",
            name="ck_guest_invitation_role",
        ),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_groups.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    created_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    redeemed_by_uid: Mapped[str | None] = mapped_column(String(128))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class GuestGroupEntry(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "guest_group_entries"
    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "created_by_uid",
            "client_import_key",
            name="uq_guest_entry_import_key",
        ),
        CheckConstraint(
            "kind IN ('knowledge', 'interact_session')",
            name="ck_guest_entry_kind",
        ),
        CheckConstraint("revision > 0", name="ck_guest_entry_revision"),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_groups.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    kind: Mapped[str] = mapped_column(String(30), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    data: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    updated_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    client_import_key: Mapped[str | None] = mapped_column(String(64))
    revision: Mapped[int] = mapped_column(Integer, default=1, nullable=False)


class GuestGroupEntryRevision(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "guest_group_entry_revisions"
    __table_args__ = (
        UniqueConstraint(
            "entry_id", "revision", name="uq_guest_entry_revision_number"
        ),
    )

    entry_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("guest_group_entries.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    edited_by_uid: Mapped[str] = mapped_column(String(128), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    data: Mapped[dict] = mapped_column(JSON, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class GuestActionRateLimit(Base):
    __tablename__ = "guest_action_rate_limits"
    __table_args__ = (
        CheckConstraint("hits > 0", name="ck_guest_rate_limit_hits"),
    )

    firebase_uid: Mapped[str] = mapped_column(String(128), primary_key=True)
    action: Mapped[str] = mapped_column(String(32), primary_key=True)
    window_start: Mapped[int] = mapped_column(Integer, nullable=False)
    hits: Mapped[int] = mapped_column(Integer, nullable=False)
