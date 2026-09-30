import enum
import uuid

from sqlalchemy import Enum, ForeignKey, ForeignKeyConstraint, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class TeamStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"


class Team(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "teams"
    __table_args__ = (
        UniqueConstraint(
            "organisation_id", "name", name="uq_teams_organisation_name"
        ),
        UniqueConstraint("id", "organisation_id", name="uq_teams_id_organisation"),
        ForeignKeyConstraint(
            ["department_id", "organisation_id"],
            ["departments.id", "departments.organisation_id"],
            name="fk_teams_department_organisation",
        ),
    )

    organisation_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("organisations.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    department_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        index=True,
        nullable=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[TeamStatus] = mapped_column(
        Enum(
            TeamStatus,
            name="team_status",
            values_callable=lambda values: [item.value for item in values],
        ),
        default=TeamStatus.ACTIVE,
        nullable=False,
    )