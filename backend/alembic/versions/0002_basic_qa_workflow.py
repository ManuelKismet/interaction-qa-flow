"""Add accepted answers, comments, and answer reactions."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

reaction_type = sa.Enum("helpful", "not_helpful", name="reaction_type")


def upgrade() -> None:
    op.add_column("questions", sa.Column("accepted_answer_id", sa.Uuid(), nullable=True))
    op.create_index(
        "ix_questions_accepted_answer_id",
        "questions",
        ["accepted_answer_id"],
    )
    op.create_foreign_key(
        "fk_questions_accepted_answer_id_answers",
        "questions",
        "answers",
        ["accepted_answer_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "comments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("answer_id", sa.Uuid(), nullable=True),
        sa.Column("author_id", sa.Uuid(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
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
        sa.ForeignKeyConstraint(["answer_id"], ["answers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["author_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["question_id"], ["questions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_comments_organisation_id", "comments", ["organisation_id"])
    op.create_index("ix_comments_question_id", "comments", ["question_id"])
    op.create_index("ix_comments_answer_id", "comments", ["answer_id"])

    op.create_table(
        "answer_reactions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("answer_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("reaction", reaction_type, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["answer_id"], ["answers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("answer_id", "user_id", name="uq_answer_reaction_user"),
    )
    op.create_index(
        "ix_answer_reactions_organisation_id",
        "answer_reactions",
        ["organisation_id"],
    )
    op.create_index("ix_answer_reactions_answer_id", "answer_reactions", ["answer_id"])


def downgrade() -> None:
    op.drop_index("ix_answer_reactions_answer_id", table_name="answer_reactions")
    op.drop_index("ix_answer_reactions_organisation_id", table_name="answer_reactions")
    op.drop_table("answer_reactions")
    reaction_type.drop(op.get_bind(), checkfirst=True)
    op.drop_index("ix_comments_answer_id", table_name="comments")
    op.drop_index("ix_comments_question_id", table_name="comments")
    op.drop_index("ix_comments_organisation_id", table_name="comments")
    op.drop_table("comments")
    op.drop_constraint(
        "fk_questions_accepted_answer_id_answers",
        "questions",
        type_="foreignkey",
    )
    op.drop_index("ix_questions_accepted_answer_id", table_name="questions")
    op.drop_column("questions", "accepted_answer_id")