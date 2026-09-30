import uuid

from sqlalchemy import ForeignKey, ForeignKeyConstraint, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class TeamMembership(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "team_memberships"
    __table_args__ = (
        UniqueConstraint(
            "team_id", "user_id", name="uq_team_memberships_team_user"
        ),
        ForeignKeyConstraint(
            ["team_id", "organisation_id"],
            ["teams.id", "teams.organisation_id"],
            name="fk_team_memberships_team_organisation",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["user_id", "organisation_id"],
            ["users.id", "users.organisation_id"],
            name="fk_team_memberships_user_organisation",
            ondelete="CASCADE",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organisations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    team_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        index=True,
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        index=True,
        nullable=False,
    )