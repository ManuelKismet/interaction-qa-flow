"""Add canonical question governance and duplicate suggestions."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

duplicate_suggestion_status = sa.Enum(
    "open",
    "accepted",
    "rejected",
    name="duplicate_suggestion_status",
)


def upgrade() -> None:
    op.create_check_constraint(
        "ck_questions_canonical_not_self",
        "questions",
        "canonical_question_id IS NULL OR canonical_question_id <> id",
    )
    op.create_index(
        "ix_questions_canonical_question_id",
        "questions",
        ["canonical_question_id"],
    )
    op.create_table(
        "duplicate_suggestions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("suggested_canonical_question_id", sa.Uuid(), nullable=False),
        sa.Column("submitted_by", sa.Uuid(), nullable=False),
        sa.Column("reason", sa.Text()),
        sa.Column("status", duplicate_suggestion_status, nullable=False),
        sa.Column("reviewed_by", sa.Uuid()),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
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
            ["organisation_id"], ["organisations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["question_id"], ["questions.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["suggested_canonical_question_id"],
            ["questions.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["submitted_by"], ["users.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by"], ["users.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_duplicate_suggestions_organisation_id",
        "duplicate_suggestions",
        ["organisation_id"],
    )
    op.create_index(
        "ix_duplicate_suggestions_question_id",
        "duplicate_suggestions",
        ["question_id"],
    )
    op.create_index(
        "ix_duplicate_suggestions_suggested_canonical_question_id",
        "duplicate_suggestions",
        ["suggested_canonical_question_id"],
    )
    op.create_index(
        "uq_duplicate_suggestions_open_pair",
        "duplicate_suggestions",
        ["question_id", "suggested_canonical_question_id"],
        unique=True,
        postgresql_where=sa.text("status = 'open'"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_duplicate_suggestions_open_pair",
        table_name="duplicate_suggestions",
    )
    op.drop_index(
        "ix_duplicate_suggestions_suggested_canonical_question_id",
        table_name="duplicate_suggestions",
    )
    op.drop_index(
        "ix_duplicate_suggestions_question_id",
        table_name="duplicate_suggestions",
    )
    op.drop_index(
        "ix_duplicate_suggestions_organisation_id",
        table_name="duplicate_suggestions",
    )
    op.drop_table("duplicate_suggestions")
    duplicate_suggestion_status.drop(op.get_bind(), checkfirst=True)
    op.drop_index("ix_questions_canonical_question_id", table_name="questions")
    op.drop_constraint(
        "ck_questions_canonical_not_self", "questions", type_="check"
    )