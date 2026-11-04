"""Add explicit team visibility for Knowledge questions."""

from alembic import op

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # PostgreSQL enum values must be committed before use. No data is rewritten.
    if op.get_bind().dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            op.execute("ALTER TYPE question_visibility ADD VALUE IF NOT EXISTS 'team'")


def downgrade() -> None:
    # Removing a PostgreSQL enum value would invalidate retained question/version
    # rows. Keep the additive value; never broaden restricted content on rollback.
    pass
