"""Add recoverable guest-group archives and accepted admin transfers."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0012"
down_revision: str | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "guest_groups",
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "guest_groups",
        sa.Column("archived_by_uid", sa.String(length=128), nullable=True),
    )
    op.create_table(
        "guest_group_admin_transfers",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("group_id", sa.Uuid(), nullable=False),
        sa.Column("requested_by_uid", sa.String(length=128), nullable=False),
        sa.Column("target_membership_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')",
            name="ck_guest_admin_transfer_status",
        ),
        sa.ForeignKeyConstraint(["group_id"], ["guest_groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["target_membership_id"],
            ["guest_group_memberships.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_guest_group_admin_transfers_group_id",
        "guest_group_admin_transfers",
        ["group_id"],
    )
    op.create_index(
        "uq_guest_admin_transfer_pending_group",
        "guest_group_admin_transfers",
        ["group_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
        sqlite_where=sa.text("status = 'pending'"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_guest_admin_transfer_pending_group",
        table_name="guest_group_admin_transfers",
    )
    op.drop_index(
        "ix_guest_group_admin_transfers_group_id",
        table_name="guest_group_admin_transfers",
    )
    op.drop_table("guest_group_admin_transfers")
    op.drop_column("guest_groups", "archived_by_uid")
    op.drop_column("guest_groups", "archived_at")
