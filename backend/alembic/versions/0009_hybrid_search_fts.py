"""Add a PostgreSQL full-text index for question search."""

from collections.abc import Sequence

from alembic import op

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX ix_questions_search_fts
        ON questions USING gin (
            to_tsvector(
                'simple',
                coalesce(title, '') || ' ' || coalesce(body, '')
            )
        )
        """
    )


def downgrade() -> None:
    op.drop_index("ix_questions_search_fts", table_name="questions")
