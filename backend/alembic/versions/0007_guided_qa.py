"""Add native Guided Q&A and knowledge proposals."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

template_status = sa.Enum("active", "archived", name="guided_template_status")
session_status = sa.Enum("draft", "active", "completed", "archived", name="guided_session_status")
session_visibility = sa.Enum("private", "department", "team", "organisation", name="guided_session_visibility")
question_scope = sa.Enum("shared", "participant", name="guided_question_scope")
question_source = sa.Enum("template", "manual", "follow_up", name="guided_question_source")
proposal_status = sa.Enum("pending", "accepted", "rejected", "duplicate", name="knowledge_proposal_status")


def timestamps() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    ]


def upgrade() -> None:
    op.create_table(
        "guided_templates",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("department_id", sa.Uuid()),
        sa.Column("team_id", sa.Uuid()),
        sa.Column("status", template_status, nullable=False),
        sa.Column("current_version", sa.Integer(), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["department_id", "organisation_id"], ["departments.id", "departments.organisation_id"], name="fk_guided_templates_department_org"),
        sa.ForeignKeyConstraint(["team_id", "organisation_id"], ["teams.id", "teams.organisation_id"], name="fk_guided_templates_team_org"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_templates_id_org"),
        sa.UniqueConstraint("organisation_id", "created_by", "name", name="uq_guided_templates_owner_name"),
    )
    op.create_table(
        "guided_template_versions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("template_id", sa.Uuid(), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["template_id", "organisation_id"], ["guided_templates.id", "guided_templates.organisation_id"], name="fk_guided_template_versions_template_org", ondelete="CASCADE"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_template_versions_id_org"),
        sa.UniqueConstraint("template_id", "version_number", name="uq_guided_template_version"),
    )
    op.create_table(
        "guided_template_questions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("template_version_id", sa.Uuid(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("scope", question_scope, nullable=False),
        sa.Column("participant_reference", sa.String(255)),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("parent_template_question_id", sa.Uuid()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["template_version_id", "organisation_id"], ["guided_template_versions.id", "guided_template_versions.organisation_id"], name="fk_guided_template_questions_version_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["parent_template_question_id", "organisation_id"], ["guided_template_questions.id", "guided_template_questions.organisation_id"], name="fk_guided_template_questions_parent_org", ondelete="CASCADE"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_template_questions_id_org"),
    )
    op.create_table(
        "guided_sessions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("template_id", sa.Uuid()),
        sa.Column("template_version_id", sa.Uuid()),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("owner_text", sa.String(255)),
        sa.Column("context_reference", sa.Text()),
        sa.Column("department_id", sa.Uuid()),
        sa.Column("team_id", sa.Uuid()),
        sa.Column("visibility", session_visibility, nullable=False),
        sa.Column("status", session_status, nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["department_id", "organisation_id"], ["departments.id", "departments.organisation_id"], name="fk_guided_sessions_department_org"),
        sa.ForeignKeyConstraint(["team_id", "organisation_id"], ["teams.id", "teams.organisation_id"], name="fk_guided_sessions_team_org"),
        sa.ForeignKeyConstraint(["template_id", "organisation_id"], ["guided_templates.id", "guided_templates.organisation_id"], name="fk_guided_sessions_template_org"),
        sa.ForeignKeyConstraint(["template_version_id", "organisation_id"], ["guided_template_versions.id", "guided_template_versions.organisation_id"], name="fk_guided_sessions_template_version_org"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_sessions_id_org"),
    )
    op.create_table(
        "guided_participants",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("role_label", sa.String(255)),
        sa.Column("linked_user_id", sa.Uuid()),
        sa.Column("notes", sa.Text()),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id", "organisation_id"], ["guided_sessions.id", "guided_sessions.organisation_id"], name="fk_guided_participants_session_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["linked_user_id", "organisation_id"], ["users.id", "users.organisation_id"], name="fk_guided_participants_user_org"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_participants_id_org"),
    )
    op.create_table(
        "guided_questions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("template_question_id", sa.Uuid()),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("scope", question_scope, nullable=False),
        sa.Column("target_participant_id", sa.Uuid()),
        sa.Column("source", question_source, nullable=False),
        sa.Column("main_order_index", sa.Integer()),
        sa.Column("branch_order_index", sa.Integer()),
        sa.Column("triggering_answer_id", sa.Uuid()),
        sa.Column("knowledge_question_id", sa.Uuid()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id", "organisation_id"], ["guided_sessions.id", "guided_sessions.organisation_id"], name="fk_guided_questions_session_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["target_participant_id", "organisation_id"], ["guided_participants.id", "guided_participants.organisation_id"], name="fk_guided_questions_participant_org"),
        sa.ForeignKeyConstraint(["template_question_id"], ["guided_template_questions.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["knowledge_question_id"], ["questions.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_questions_id_org"),
    )
    op.create_table(
        "guided_answers",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("question_id", sa.Uuid(), nullable=False),
        sa.Column("participant_id", sa.Uuid(), nullable=False),
        sa.Column("answered_by_user_id", sa.Uuid()),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("branches_collapsed", sa.Boolean(), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id", "organisation_id"], ["guided_sessions.id", "guided_sessions.organisation_id"], name="fk_guided_answers_session_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["question_id", "organisation_id"], ["guided_questions.id", "guided_questions.organisation_id"], name="fk_guided_answers_question_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["participant_id", "organisation_id"], ["guided_participants.id", "guided_participants.organisation_id"], name="fk_guided_answers_participant_org"),
        sa.ForeignKeyConstraint(["answered_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_guided_answers_id_org"),
        sa.UniqueConstraint("question_id", "participant_id", name="uq_guided_answer_question_participant"),
    )
    op.create_foreign_key("fk_guided_questions_triggering_answer_org", "guided_questions", "guided_answers", ["triggering_answer_id", "organisation_id"], ["id", "organisation_id"])
    op.create_table(
        "guided_session_revisions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("revision_number", sa.Integer(), nullable=False),
        sa.Column("saved_by", sa.Uuid(), nullable=False),
        sa.Column("summary", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id", "organisation_id"], ["guided_sessions.id", "guided_sessions.organisation_id"], name="fk_guided_session_revisions_session_org", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["saved_by"], ["users.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint("session_id", "revision_number", name="uq_guided_session_revision"),
    )
    op.create_table(
        "knowledge_proposals",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("guided_session_id", sa.Uuid(), nullable=False),
        sa.Column("guided_question_id", sa.Uuid(), nullable=False),
        sa.Column("guided_answer_id", sa.Uuid(), nullable=False),
        sa.Column("proposed_by", sa.Uuid(), nullable=False),
        sa.Column("proposed_question_text", sa.Text(), nullable=False),
        sa.Column("proposed_answer_text", sa.Text(), nullable=False),
        sa.Column("department_id", sa.Uuid()),
        sa.Column("team_id", sa.Uuid()),
        sa.Column("status", proposal_status, nullable=False),
        sa.Column("reviewed_by", sa.Uuid()),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("created_question_id", sa.Uuid()),
        sa.Column("linked_question_id", sa.Uuid()),
        *timestamps(),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["guided_session_id", "organisation_id"], ["guided_sessions.id", "guided_sessions.organisation_id"], name="fk_knowledge_proposals_session_org"),
        sa.ForeignKeyConstraint(["guided_question_id", "organisation_id"], ["guided_questions.id", "guided_questions.organisation_id"], name="fk_knowledge_proposals_question_org"),
        sa.ForeignKeyConstraint(["guided_answer_id", "organisation_id"], ["guided_answers.id", "guided_answers.organisation_id"], name="fk_knowledge_proposals_answer_org"),
        sa.ForeignKeyConstraint(["proposed_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["department_id", "organisation_id"], ["departments.id", "departments.organisation_id"], name="fk_knowledge_proposals_department_org"),
        sa.ForeignKeyConstraint(["team_id", "organisation_id"], ["teams.id", "teams.organisation_id"], name="fk_knowledge_proposals_team_org"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_question_id"], ["questions.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["linked_question_id"], ["questions.id"], ondelete="SET NULL"),
    )

    for table, columns in {
        "guided_templates": ("organisation_id", "created_by", "department_id", "team_id"),
        "guided_template_versions": ("organisation_id", "template_id"),
        "guided_template_questions": ("organisation_id", "template_version_id", "parent_template_question_id"),
        "guided_sessions": ("organisation_id", "created_by", "template_id", "department_id", "team_id", "status"),
        "guided_participants": ("organisation_id", "session_id"),
        "guided_questions": ("organisation_id", "session_id", "target_participant_id", "triggering_answer_id", "deleted_at"),
        "guided_answers": ("organisation_id", "session_id", "question_id", "participant_id"),
        "guided_session_revisions": ("organisation_id", "session_id"),
        "knowledge_proposals": ("organisation_id", "status", "guided_session_id"),
    }.items():
        for column in columns:
            op.create_index(f"ix_{table}_{column}", table, [column])


def downgrade() -> None:
    for table in (
        "knowledge_proposals",
        "guided_session_revisions",
    ):
        op.drop_table(table)
    op.drop_constraint("fk_guided_questions_triggering_answer_org", "guided_questions", type_="foreignkey")
    op.drop_table("guided_answers")
    for table in (
        "guided_questions",
        "guided_participants",
        "guided_sessions",
        "guided_template_questions",
        "guided_template_versions",
        "guided_templates",
    ):
        op.drop_table(table)
    for value in (proposal_status, question_source, question_scope, session_visibility, session_status, template_status):
        value.drop(op.get_bind(), checkfirst=True)