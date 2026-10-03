"""Add isolated shared guest groups and content."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "guest_groups",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("created_by_uid", sa.String(length=128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "guest_group_memberships",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("firebase_uid", sa.String(length=128), nullable=False),
        sa.Column("display_name", sa.String(length=80), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("approved_by_uid", sa.String(length=128)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "role IN ('admin', 'editor', 'contributor', 'viewer')",
            name="ck_guest_membership_role",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'active', 'removed')",
            name="ck_guest_membership_status",
        ),
        sa.ForeignKeyConstraint(["group_id"], ["guest_groups.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "group_id", "firebase_uid", name="uq_guest_membership_group_uid"
        ),
    )
    op.create_index(
        "ix_guest_group_memberships_group_id",
        "guest_group_memberships",
        ["group_id"],
    )
    op.create_index(
        "ix_guest_group_memberships_firebase_uid",
        "guest_group_memberships",
        ["firebase_uid"],
    )
    op.create_table(
        "guest_group_invitations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("created_by_uid", sa.String(length=128), nullable=False),
        sa.Column("redeemed_by_uid", sa.String(length=128)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "role IN ('editor', 'contributor', 'viewer')",
            name="ck_guest_invitation_role",
        ),
        sa.ForeignKeyConstraint(["group_id"], ["guest_groups.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash", name="uq_guest_invitation_token_hash"),
    )
    op.create_index(
        "ix_guest_group_invitations_group_id",
        "guest_group_invitations",
        ["group_id"],
    )
    op.create_table(
        "guest_group_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("data", sa.JSON(), nullable=False),
        sa.Column("created_by_uid", sa.String(length=128), nullable=False),
        sa.Column("updated_by_uid", sa.String(length=128), nullable=False),
        sa.Column("client_import_key", sa.String(length=64)),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind IN ('knowledge', 'interact_session')",
            name="ck_guest_entry_kind",
        ),
        sa.CheckConstraint("revision > 0", name="ck_guest_entry_revision"),
        sa.ForeignKeyConstraint(["group_id"], ["guest_groups.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "group_id",
            "created_by_uid",
            "client_import_key",
            name="uq_guest_entry_import_key",
        ),
    )
    op.create_index(
        "ix_guest_group_entries_group_id", "guest_group_entries", ["group_id"]
    )
    op.create_table(
        "guest_group_entry_revisions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("entry_id", sa.Uuid(), nullable=False),
        sa.Column("edited_by_uid", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("data", sa.JSON(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["entry_id"], ["guest_group_entries.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "entry_id", "revision", name="uq_guest_entry_revision_number"
        ),
    )
    op.create_index(
        "ix_guest_group_entry_revisions_entry_id",
        "guest_group_entry_revisions",
        ["entry_id"],
    )
    op.create_table(
        "guest_action_rate_limits",
        sa.Column("firebase_uid", sa.String(length=128), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("window_start", sa.Integer(), nullable=False),
        sa.Column("hits", sa.Integer(), nullable=False),
        sa.CheckConstraint("hits > 0", name="ck_guest_rate_limit_hits"),
        sa.PrimaryKeyConstraint("firebase_uid", "action"),
    )


def downgrade() -> None:
    op.drop_table("guest_action_rate_limits")
    op.drop_index(
        "ix_guest_group_entry_revisions_entry_id",
        table_name="guest_group_entry_revisions",
    )
    op.drop_table("guest_group_entry_revisions")
    op.drop_index("ix_guest_group_entries_group_id", table_name="guest_group_entries")
    op.drop_table("guest_group_entries")
    op.drop_index(
        "ix_guest_group_invitations_group_id",
        table_name="guest_group_invitations",
    )
    op.drop_table("guest_group_invitations")
    op.drop_index(
        "ix_guest_group_memberships_firebase_uid",
        table_name="guest_group_memberships",
    )
    op.drop_index(
        "ix_guest_group_memberships_group_id",
        table_name="guest_group_memberships",
    )
    op.drop_table("guest_group_memberships")
    op.drop_table("guest_groups")
