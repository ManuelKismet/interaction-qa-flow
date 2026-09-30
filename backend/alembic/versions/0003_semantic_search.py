"""Add tenant-aware semantic question search."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.add_column("users", sa.Column("department_id", sa.Uuid(), nullable=True))
    op.create_index("ix_users_department_id", "users", ["department_id"])
    op.create_foreign_key(
        "fk_users_department_id_departments",
        "users",
        "departments",
        ["department_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "question_embeddings",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("embedding", Vector(1536), nullable=False),
        sa.Column("embedding_model", sa.String(length=255), nullable=False),
        sa.Column("source_hash", sa.String(length=64), nullable=False),
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
        sa.ForeignKeyConstraint(
            ["organisation_id"],
            ["organisations.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["question_id"],
            ["questions.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("question_id", name="uq_question_embeddings_question_id"),
    )
    op.create_index(
        "ix_question_embeddings_organisation_id",
        "question_embeddings",
        ["organisation_id"],
    )
    op.create_index(
        "ix_question_embeddings_embedding_hnsw",
        "question_embeddings",
        ["embedding"],
        postgresql_using="hnsw",
        postgresql_ops={"embedding": "vector_cosine_ops"},
    )


def downgrade() -> None:
    op.drop_index(
        "ix_question_embeddings_embedding_hnsw",
        table_name="question_embeddings",
        postgresql_using="hnsw",
    )
    op.drop_index(
        "ix_question_embeddings_organisation_id",
        table_name="question_embeddings",
    )
    op.drop_table("question_embeddings")
    op.drop_constraint(
        "fk_users_department_id_departments",
        "users",
        type_="foreignkey",
    )
    op.drop_index("ix_users_department_id", table_name="users")
    op.drop_column("users", "department_id")