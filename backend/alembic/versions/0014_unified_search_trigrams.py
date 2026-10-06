"""Add isolated private embeddings and trigram indexes."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0014"
down_revision: str | None = "0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    from pgvector.sqlalchemy import Vector

    op.add_column(
        "personal_workspace_items",
        sa.Column("knowledge_embedding", Vector(1536), nullable=True),
    )
    op.add_column(
        "personal_workspace_items",
        sa.Column("embedding_model", sa.String(255), nullable=True),
    )
    op.add_column(
        "personal_workspace_items",
        sa.Column("embedding_source_hash", sa.String(64), nullable=True),
    )
    op.add_column(
        "guest_group_entries",
        sa.Column("knowledge_embedding", Vector(1536), nullable=True),
    )
    op.add_column(
        "guest_group_entries",
        sa.Column("embedding_model", sa.String(255), nullable=True),
    )
    op.add_column(
        "guest_group_entries",
        sa.Column("embedding_source_hash", sa.String(64), nullable=True),
    )
    op.execute(
        "CREATE INDEX ix_questions_title_trgm "
        "ON questions USING gin (title gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX ix_questions_body_trgm "
        "ON questions USING gin (body gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX ix_answers_body_trgm "
        "ON answers USING gin (body gin_trgm_ops)"
    )


def downgrade() -> None:
    op.drop_index("ix_answers_body_trgm", table_name="answers")
    op.drop_index("ix_questions_body_trgm", table_name="questions")
    op.drop_index("ix_questions_title_trgm", table_name="questions")
    op.drop_column("guest_group_entries", "embedding_source_hash")
    op.drop_column("guest_group_entries", "embedding_model")
    op.drop_column("guest_group_entries", "knowledge_embedding")
    op.drop_column("personal_workspace_items", "embedding_source_hash")
    op.drop_column("personal_workspace_items", "embedding_model")
    op.drop_column("personal_workspace_items", "knowledge_embedding")
