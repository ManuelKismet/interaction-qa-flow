"""Map Firebase identities to server-managed users."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "firebase_uid_mappings",
        sa.Column("firebase_uid", sa.String(length=128), primary_key=True),
        sa.Column("user_id", sa.Uuid(), nullable=False),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_firebase_uid_mappings_user"),
    )
    op.create_index(
        "ix_firebase_uid_mappings_user_id",
        "firebase_uid_mappings",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_firebase_uid_mappings_user_id", table_name="firebase_uid_mappings")
    op.drop_table("firebase_uid_mappings")
