"""Add answer governance, review, version, and audit data."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

challenge_type = sa.Enum(
    "outdated",
    "incorrect",
    "unclear",
    "incomplete",
    "suggest_update",
    name="challenge_type",
)
challenge_status = sa.Enum(
    "open",
    "accepted",
    "rejected",
    "withdrawn",
    name="challenge_status",
)
answer_status = sa.Enum(
    "proposed",
    "community",
    "verified",
    "superseded",
    "rejected",
    name="answer_status",
    create_type=False,
)


def upgrade() -> None:
    op.add_column("answers", sa.Column("review_due_at", sa.DateTime(timezone=True)))
    op.add_column("answers", sa.Column("last_reviewed_at", sa.DateTime(timezone=True)))
    op.add_column("answers", sa.Column("last_reviewed_by", sa.Uuid()))
    op.create_index("ix_answers_review_due_at", "answers", ["review_due_at"])
    op.create_foreign_key(
        "fk_answers_last_reviewed_by_users",
        "answers",
        "users",
        ["last_reviewed_by"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "uq_answers_verified_question",
        "answers",
        ["question_id"],
        unique=True,
        postgresql_where=sa.text("status = 'verified'"),
    )

    op.create_table(
        "department_answer_owners",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("department_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["department_id"], ["departments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("department_id", "user_id", name="uq_department_answer_owners_department_user"),
    )
    op.create_index("ix_department_answer_owners_organisation_id", "department_answer_owners", ["organisation_id"])
    op.create_index("ix_department_answer_owners_department_id", "department_answer_owners", ["department_id"])
    op.create_index("ix_department_answer_owners_user_id", "department_answer_owners", ["user_id"])

    op.create_table(
        "answer_challenges",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("answer_id", sa.Uuid(), nullable=False),
        sa.Column("submitted_by", sa.Uuid(), nullable=False),
        sa.Column("type", challenge_type, nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("suggested_answer", sa.Text()),
        sa.Column("status", challenge_status, nullable=False),
        sa.Column("reviewed_by", sa.Uuid()),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("reviewer_note", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["answer_id"], ["answers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["submitted_by"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_answer_challenges_organisation_id", "answer_challenges", ["organisation_id"])
    op.create_index("ix_answer_challenges_answer_id", "answer_challenges", ["answer_id"])
    op.create_index("ix_answer_challenges_status", "answer_challenges", ["status"])

    op.create_table(
        "answer_versions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("answer_id", sa.Uuid(), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status_snapshot", answer_status, nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=False),
        sa.Column("change_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["answer_id"], ["answers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["question_id"], ["questions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("question_id", "version_number", name="uq_answer_versions_question_number"),
    )
    op.create_index("ix_answer_versions_organisation_id", "answer_versions", ["organisation_id"])
    op.create_index("ix_answer_versions_question_id", "answer_versions", ["question_id"])
    op.create_index("ix_answer_versions_answer_id", "answer_versions", ["answer_id"])

    op.create_table(
        "audit_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("actor_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("entity_type", sa.String(length=80), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("metadata", sa.JSON()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_events_organisation_id", "audit_events", ["organisation_id"])
    op.create_index("ix_audit_events_actor_id", "audit_events", ["actor_id"])
    op.create_index("ix_audit_events_action", "audit_events", ["action"])


def downgrade() -> None:
    op.drop_index("ix_audit_events_action", table_name="audit_events")
    op.drop_index("ix_audit_events_actor_id", table_name="audit_events")
    op.drop_index("ix_audit_events_organisation_id", table_name="audit_events")
    op.drop_table("audit_events")
    op.drop_index("ix_answer_versions_answer_id", table_name="answer_versions")
    op.drop_index("ix_answer_versions_question_id", table_name="answer_versions")
    op.drop_index("ix_answer_versions_organisation_id", table_name="answer_versions")
    op.drop_table("answer_versions")
    op.drop_index("ix_answer_challenges_status", table_name="answer_challenges")
    op.drop_index("ix_answer_challenges_answer_id", table_name="answer_challenges")
    op.drop_index("ix_answer_challenges_organisation_id", table_name="answer_challenges")
    op.drop_table("answer_challenges")
    challenge_status.drop(op.get_bind(), checkfirst=True)
    challenge_type.drop(op.get_bind(), checkfirst=True)
    op.drop_index("ix_department_answer_owners_user_id", table_name="department_answer_owners")
    op.drop_index("ix_department_answer_owners_department_id", table_name="department_answer_owners")
    op.drop_index("ix_department_answer_owners_organisation_id", table_name="department_answer_owners")
    op.drop_table("department_answer_owners")
    op.drop_index("uq_answers_verified_question", table_name="answers")
    op.drop_constraint("fk_answers_last_reviewed_by_users", "answers", type_="foreignkey")
    op.drop_index("ix_answers_review_due_at", table_name="answers")
    op.drop_column("answers", "last_reviewed_by")
    op.drop_column("answers", "last_reviewed_at")
    op.drop_column("answers", "review_due_at")