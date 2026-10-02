"""Record question revisions, recoverable archives, and change requests."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

question_status = sa.Enum(
    "open",
    "answered",
    "resolved",
    "under_review",
    "archived",
    name="question_status",
    create_type=False,
)
question_visibility = sa.Enum(
    "organisation",
    "department",
    "private",
    name="question_visibility",
    create_type=False,
)
change_request_status = sa.Enum(
    "pending",
    "approved",
    "rejected",
    name="question_change_request_status",
)


def upgrade() -> None:
    op.add_column("questions", sa.Column("protected_at", sa.DateTime(timezone=True)))
    op.add_column(
        "questions", sa.Column("contribution_started_at", sa.DateTime(timezone=True))
    )
    op.add_column("questions", sa.Column("archived_at", sa.DateTime(timezone=True)))
    op.add_column("questions", sa.Column("archived_by", sa.Uuid()))
    op.add_column("questions", sa.Column("archive_reason", sa.Text()))
    op.add_column("questions", sa.Column("status_before_archive", question_status))
    op.create_foreign_key(
        "fk_questions_archived_by_users",
        "questions",
        "users",
        ["archived_by"],
        ["id"],
        ondelete="SET NULL",
    )
    op.execute(
        """
        UPDATE questions
        SET protected_at = coalesce(resolved_at, updated_at)
        WHERE accepted_answer_id IS NOT NULL
           OR EXISTS (
                SELECT 1 FROM answers
                WHERE answers.question_id = questions.id
                  AND answers.organisation_id = questions.organisation_id
                  AND answers.status = 'verified'
           )
        """
    )
    op.execute(
        """
        UPDATE questions
        SET contribution_started_at = updated_at
        WHERE EXISTS (
                SELECT 1 FROM answers
                WHERE answers.question_id = questions.id
                  AND answers.organisation_id = questions.organisation_id
           )
           OR EXISTS (
                SELECT 1 FROM comments
                WHERE comments.question_id = questions.id
                  AND comments.organisation_id = questions.organisation_id
           )
        """
    )
    op.execute(
        """
        UPDATE questions
        SET archived_at = updated_at,
            archive_reason = 'Archived before ownership audit metadata was available'
        WHERE status = 'archived'
        """
    )
    op.execute(
        """
        UPDATE questions
        SET status_before_archive = CASE
                WHEN accepted_answer_id IS NOT NULL OR resolved_at IS NOT NULL
                    THEN 'resolved'
                WHEN EXISTS (
                    SELECT 1 FROM answers
                    WHERE answers.question_id = questions.id
                      AND answers.organisation_id = questions.organisation_id
                ) THEN 'answered'
                ELSE 'open'
            END
        WHERE status = 'archived'
        """
    )

    op.add_column("answers", sa.Column("archived_at", sa.DateTime(timezone=True)))
    op.add_column("answers", sa.Column("archived_by", sa.Uuid()))
    op.add_column("answers", sa.Column("archive_reason", sa.Text()))
    op.add_column("answers", sa.Column("protected_at", sa.DateTime(timezone=True)))
    op.create_foreign_key(
        "fk_answers_archived_by_users",
        "answers",
        "users",
        ["archived_by"],
        ["id"],
        ondelete="SET NULL",
    )
    op.execute(
        """
        UPDATE answers
        SET protected_at = coalesce(verified_at, updated_at)
        WHERE status = 'verified'
           OR id IN (
                SELECT accepted_answer_id
                FROM questions
                WHERE accepted_answer_id IS NOT NULL
           )
        """
    )

    op.create_table(
        "question_versions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("body", sa.Text()),
        sa.Column("status_snapshot", question_status, nullable=False),
        sa.Column("visibility_snapshot", question_visibility, nullable=False),
        sa.Column("department_id", sa.Uuid()),
        sa.Column("team_id", sa.Uuid()),
        sa.Column("changed_by", sa.Uuid(), nullable=False),
        sa.Column("change_reason", sa.Text(), nullable=False),
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
            ["department_id"], ["departments.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(["team_id"], ["teams.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "question_id",
            "version_number",
            name="uq_question_versions_question_number",
        ),
    )
    op.create_index(
        "ix_question_versions_organisation_id",
        "question_versions",
        ["organisation_id"],
    )
    op.create_index(
        "ix_question_versions_question_id",
        "question_versions",
        ["question_id"],
    )

    op.create_table(
        "question_change_requests",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("requested_by", sa.Uuid(), nullable=False),
        sa.Column("proposed_title", sa.Text()),
        sa.Column("proposed_body", sa.Text()),
        sa.Column("change_title", sa.Boolean(), nullable=False),
        sa.Column("change_body", sa.Boolean(), nullable=False),
        sa.Column("archive_requested", sa.Boolean(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("status", change_request_status, nullable=False),
        sa.Column("reviewed_by", sa.Uuid()),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("review_note", sa.Text()),
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
            ["requested_by"], ["users.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_question_change_requests_organisation_id",
        "question_change_requests",
        ["organisation_id"],
    )
    op.create_index(
        "ix_question_change_requests_question_id",
        "question_change_requests",
        ["question_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_question_change_requests_question_id",
        table_name="question_change_requests",
    )
    op.drop_index(
        "ix_question_change_requests_organisation_id",
        table_name="question_change_requests",
    )
    op.drop_table("question_change_requests")
    op.drop_index("ix_question_versions_question_id", table_name="question_versions")
    op.drop_index(
        "ix_question_versions_organisation_id", table_name="question_versions"
    )
    op.drop_table("question_versions")
    op.drop_constraint(
        "fk_answers_archived_by_users", "answers", type_="foreignkey"
    )
    op.drop_column("answers", "protected_at")
    op.drop_column("answers", "archive_reason")
    op.drop_column("answers", "archived_by")
    op.drop_column("answers", "archived_at")
    op.drop_constraint(
        "fk_questions_archived_by_users", "questions", type_="foreignkey"
    )
    op.drop_column("questions", "status_before_archive")
    op.drop_column("questions", "archive_reason")
    op.drop_column("questions", "archived_by")
    op.drop_column("questions", "archived_at")
    op.drop_column("questions", "protected_at")
    op.drop_column("questions", "contribution_started_at")
    op.execute("DROP TYPE question_change_request_status")
