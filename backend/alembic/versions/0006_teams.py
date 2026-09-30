"""Add operational teams and memberships."""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

team_status = sa.Enum("active", "inactive", name="team_status")


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_departments_id_organisation", "departments", ["id", "organisation_id"]
    )
    op.create_unique_constraint(
        "uq_users_id_organisation", "users", ["id", "organisation_id"]
    )
    op.create_table(
        "teams",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("department_id", sa.Uuid()),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("status", team_status, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_teams_department_organisation",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("organisation_id", "name", name="uq_teams_organisation_name"),
        sa.UniqueConstraint("id", "organisation_id", name="uq_teams_id_organisation"),
    )
    op.create_index("ix_teams_organisation_id", "teams", ["organisation_id"])
    op.create_index("ix_teams_department_id", "teams", ["department_id"])
    op.create_table(
        "team_memberships",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("team_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organisation_id"], ["organisations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_team_memberships_team_organisation",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_team_memberships_user_organisation",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("team_id", "user_id", name="uq_team_memberships_team_user"),
    )
    op.create_index("ix_team_memberships_organisation_id", "team_memberships", ["organisation_id"])
    op.create_index("ix_team_memberships_team_id", "team_memberships", ["team_id"])
    op.create_index("ix_team_memberships_user_id", "team_memberships", ["user_id"])
    op.add_column("questions", sa.Column("team_id", sa.Uuid()))
    op.create_foreign_key(
        "fk_questions_team_organisation",
        "questions",
        "teams",
        ["team_id", "organisation_id"],
        ["id", "organisation_id"],
    )
    op.create_index("ix_questions_team_id", "questions", ["team_id"])


def downgrade() -> None:
    op.drop_index("ix_questions_team_id", table_name="questions")
    op.drop_constraint("fk_questions_team_organisation", "questions", type_="foreignkey")
    op.drop_column("questions", "team_id")
    op.drop_index("ix_team_memberships_user_id", table_name="team_memberships")
    op.drop_index("ix_team_memberships_team_id", table_name="team_memberships")
    op.drop_index("ix_team_memberships_organisation_id", table_name="team_memberships")
    op.drop_table("team_memberships")
    op.drop_index("ix_teams_department_id", table_name="teams")
    op.drop_index("ix_teams_organisation_id", table_name="teams")
    op.drop_table("teams")
    team_status.drop(op.get_bind(), checkfirst=True)
    op.drop_constraint("uq_users_id_organisation", "users", type_="unique")
    op.drop_constraint(
        "uq_departments_id_organisation", "departments", type_="unique"
    )