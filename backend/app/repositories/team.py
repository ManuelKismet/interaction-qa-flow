from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.department import Department
from app.models.team import Team
from app.models.team_membership import TeamMembership
from app.models.user import User


class TeamRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, entity) -> None:
        self.session.add(entity)
        await self.session.flush()

    async def list_for_organisation(
        self,
        organisation_id: UUID,
    ) -> list[tuple[Team, Department | None]]:
        rows = await self.session.execute(
            select(Team, Department)
            .outerjoin(
                Department,
                (Department.id == Team.department_id)
                & (Department.organisation_id == organisation_id),
            )
            .where(Team.organisation_id == organisation_id)
            .order_by(Team.name)
        )
        return [(row.Team, row.Department) for row in rows]

    async def get(
        self,
        team_id: UUID,
        organisation_id: UUID,
    ) -> tuple[Team, Department | None] | None:
        row = (
            await self.session.execute(
                select(Team, Department)
                .outerjoin(
                    Department,
                    (Department.id == Team.department_id)
                    & (Department.organisation_id == organisation_id),
                )
                .where(
                    Team.id == team_id,
                    Team.organisation_id == organisation_id,
                )
            )
        ).one_or_none()
        return (row.Team, row.Department) if row else None

    async def membership(
        self,
        team_id: UUID,
        user_id: UUID,
        organisation_id: UUID,
    ) -> TeamMembership | None:
        return (
            await self.session.execute(
                select(TeamMembership).where(
                    TeamMembership.team_id == team_id,
                    TeamMembership.user_id == user_id,
                    TeamMembership.organisation_id == organisation_id,
                )
            )
        ).scalar_one_or_none()

    async def members(
        self,
        team_id: UUID,
        organisation_id: UUID,
    ) -> list[tuple[TeamMembership, User]]:
        rows = await self.session.execute(
            select(TeamMembership, User)
            .join(
                User,
                (User.id == TeamMembership.user_id)
                & (User.organisation_id == organisation_id),
            )
            .where(
                TeamMembership.team_id == team_id,
                TeamMembership.organisation_id == organisation_id,
            )
            .order_by(User.display_name)
        )
        return [(row.TeamMembership, row.User) for row in rows]

    async def team_ids_for_user(
        self,
        user_id: UUID,
        organisation_id: UUID,
    ) -> list[UUID]:
        rows = await self.session.scalars(
            select(TeamMembership.team_id).where(
                TeamMembership.user_id == user_id,
                TeamMembership.organisation_id == organisation_id,
            )
        )
        return list(rows)

    async def delete(self, membership: TeamMembership) -> None:
        await self.session.delete(membership)