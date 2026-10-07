"""Add owners, scoped grants, and organisation join requests."""

from collections.abc import Sequence
from uuid import UUID, uuid4

import sqlalchemy as sa
from alembic import op

revision: str = "0015"
down_revision: str | None = "0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "organisation_owners",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("appointed_by", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["organisation_id"], ["organisations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_organisation_owners_user_organisation",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["appointed_by"], ["users.id"], ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("organisation_id", "user_id", name="uq_organisation_owners"),
    )
    op.create_index(
        "ix_organisation_owners_organisation_id",
        "organisation_owners",
        ["organisation_id"],
    )

    op.create_table(
        "organisation_permission_grants",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("permission", sa.String(length=60), nullable=False),
        sa.Column("scope_type", sa.String(length=20), nullable=False),
        sa.Column("scope_id", sa.Uuid(), nullable=True),
        sa.Column("granted_by", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_by", sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(
            ["organisation_id"], ["organisations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_organisation_permission_grants_user_organisation",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["granted_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["revoked_by"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_organisation_permission_grants_organisation_id",
        "organisation_permission_grants",
        ["organisation_id"],
    )
    op.create_index(
        "uq_organisation_permission_grants_active",
        "organisation_permission_grants",
        [
            "organisation_id",
            "user_id",
            "permission",
            "scope_type",
            "scope_id",
        ],
        unique=True,
        postgresql_where=sa.text("revoked_at IS NULL"),
        sqlite_where=sa.text("revoked_at IS NULL"),
    )

    op.create_table(
        "organisation_join_requests",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("organisation_id", sa.Uuid(), nullable=False),
        sa.Column("requester_id", sa.Uuid(), nullable=False),
        sa.Column("request_type", sa.String(length=20), nullable=False),
        sa.Column("target_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("reviewer_note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["organisation_id"], ["organisations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["requester_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_organisation_join_requests_requester_organisation",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_organisation_join_requests_organisation_id",
        "organisation_join_requests",
        ["organisation_id"],
    )
    op.create_index(
        "uq_organisation_join_requests_pending",
        "organisation_join_requests",
        ["organisation_id", "requester_id", "request_type", "target_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
        sqlite_where=sa.text("status = 'pending'"),
    )

    connection = op.get_bind()
    grants = sa.table(
        "organisation_permission_grants",
        sa.column("id", sa.Uuid()),
        sa.column("organisation_id", sa.Uuid()),
        sa.column("user_id", sa.Uuid()),
        sa.column("permission", sa.String()),
        sa.column("scope_type", sa.String()),
        sa.column("scope_id", sa.Uuid()),
        sa.column("granted_by", sa.Uuid()),
    )
    existing_admins = list(
        connection.execute(
            sa.text("SELECT id, organisation_id FROM users WHERE role = 'admin'")
        )
    )
    for user_id, organisation_id in existing_admins:
        if isinstance(user_id, str):
            user_id = UUID(user_id)
        if isinstance(organisation_id, str):
            organisation_id = UUID(organisation_id)
        connection.execute(
            sa.insert(grants).values(
                id=uuid4(),
                organisation_id=organisation_id,
                user_id=user_id,
                permission="legacy_admin",
                scope_type="organisation",
                scope_id=None,
                granted_by=user_id,
            )
        )


def downgrade() -> None:
    op.drop_index("uq_organisation_join_requests_pending", table_name="organisation_join_requests")
    op.drop_index("ix_organisation_join_requests_organisation_id", table_name="organisation_join_requests")
    op.drop_table("organisation_join_requests")
    op.drop_index("uq_organisation_permission_grants_active", table_name="organisation_permission_grants")
    op.drop_index("ix_organisation_permission_grants_organisation_id", table_name="organisation_permission_grants")
    op.drop_table("organisation_permission_grants")
    op.drop_index("ix_organisation_owners_organisation_id", table_name="organisation_owners")
    op.drop_table("organisation_owners")
