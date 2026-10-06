"""Add UID-private personal workspace items."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0013"
down_revision: str | None = "0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "personal_workspace_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("firebase_uid", sa.String(length=128), nullable=False),
        sa.Column("source_key", sa.String(length=128), nullable=False),
        sa.Column("kind", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("data", sa.JSON(), nullable=False),
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
            "kind IN ('knowledge', 'interact_session', 'template')",
            name="ck_personal_workspace_item_kind",
        ),
        sa.CheckConstraint("revision > 0", name="ck_personal_workspace_item_revision"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "firebase_uid",
            "source_key",
            name="uq_personal_workspace_item_source",
        ),
    )
    op.create_index(
        "ix_personal_workspace_items_firebase_uid",
        "personal_workspace_items",
        ["firebase_uid"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_personal_workspace_items_firebase_uid",
        table_name="personal_workspace_items",
    )
    op.drop_table("personal_workspace_items")
