from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.audit_event import AuditAction, AuditEvent
from app.models.organisation import Organisation
from app.models.team import Team
from app.models.team_membership import TeamMembership
from app.models.user import User
from app.repositories.department import DepartmentRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.department import DepartmentSummary
from app.schemas.team import (
    TeamCreate,
    TeamMemberCreate,
    TeamMembershipResponse,
    TeamResponse,
    TeamUpdate,
)
from app.schemas.user import UserSummary
from app.services.permissions import PermissionService


class TeamService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.teams = TeamRepository(session)
        self.departments = DepartmentRepository(session)
        self.governance = GovernanceRepository(session)
        self.users = UserRepository(session)
        self.permissions = PermissionService(self.users)

    async def list(self, organisation_id: UUID, user_id: UUID) -> list[TeamResponse]:
        await self.permissions.actor(user_id, organisation_id)
        return [self._response(team, department) for team, department in await self.teams.list_for_organisation(organisation_id)]

    async def get(self, team_id: UUID, organisation_id: UUID, user_id: UUID) -> TeamResponse:
        await self.permissions.actor(user_id, organisation_id)
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found")
        return self._response(*row)

    async def create(
        self,
        organisation_id: UUID,
        user_id: UUID,
        data: TeamCreate,
    ) -> TeamResponse:
        await self._lock_organisation(organisation_id)
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_permission(
            actor, "team_create", department_id=data.department_id
        )
        department = await self._department(data.department_id, organisation_id)
        team = Team(organisation_id=organisation_id, **data.model_dump())
        try:
            await self.teams.add(team)
            await self._audit(actor.id, organisation_id, AuditAction.TEAM_CREATED, team.id)
            await self.session.commit()
        except IntegrityError as error:
            await self.session.rollback()
            raise ConflictError("A team with this name already exists") from error
        await self.session.refresh(team)
        return self._response(team, department)

    async def update(
        self,
        team_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: TeamUpdate,
    ) -> TeamResponse:
        await self._lock_organisation(organisation_id)
        actor = await self.permissions.actor(user_id, organisation_id)
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found")
        team, current_department = row
        await self.permissions.require_permission(
            actor,
            "team_membership",
            department_id=team.department_id,
            team_id=team.id,
        )
        changes = data.model_dump(exclude_unset=True)
        department = current_department
        if "department_id" in changes:
            department = await self._department(changes["department_id"], organisation_id)
        for field, value in changes.items():
            setattr(team, field, value)
        try:
            await self._audit(actor.id, organisation_id, AuditAction.TEAM_UPDATED, team.id)
            await self.session.commit()
        except IntegrityError as error:
            await self.session.rollback()
            raise ConflictError("A team with this name already exists") from error
        await self.session.refresh(team)
        return self._response(team, department)

    async def add_member(
        self,
        team_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: TeamMemberCreate,
    ) -> TeamMembershipResponse:
        await self._lock_organisation(organisation_id)
        actor = await self.permissions.actor(user_id, organisation_id)
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found")
        team = row[0]
        await self.permissions.require_permission(
            actor,
            "team_membership",
            department_id=team.department_id,
            team_id=team.id,
        )
        member = await self.session.scalar(
            select(User)
            .where(
                User.id == data.user_id,
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .with_for_update()
        )
        if member is None:
            raise NotFoundError("User not found in this organisation")
        if await self.teams.membership(team_id, member.id, organisation_id):
            raise ConflictError("User is already a member of this team")
        membership = TeamMembership(
            organisation_id=organisation_id,
            team_id=team_id,
            user_id=member.id,
        )
        await self.teams.add(membership)
        await self._audit(
            actor.id,
            organisation_id,
            AuditAction.TEAM_MEMBER_ADDED,
            membership.id,
            {"team_id": str(team_id), "user_id": str(member.id)},
        )
        await self.session.commit()
        await self.session.refresh(membership)
        return self._membership_response(membership, member)

    async def remove_member(
        self,
        team_id: UUID,
        member_user_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> None:
        await self._lock_organisation(organisation_id)
        actor = await self.permissions.actor(user_id, organisation_id)
        team = await self.teams.get(team_id, organisation_id)
        if not team:
            raise NotFoundError("Team not found")
        await self.permissions.require_permission(
            actor,
            "team_membership",
            department_id=team[0].department_id,
            team_id=team_id,
        )
        membership = await self.teams.membership(
            team_id, member_user_id, organisation_id
        )
        if not membership:
            raise NotFoundError("Team membership not found")
        membership_id = membership.id
        await self.teams.delete(membership)
        await self._audit(
            actor.id,
            organisation_id,
            AuditAction.TEAM_MEMBER_REMOVED,
            membership_id,
            {"team_id": str(team_id), "user_id": str(member_user_id)},
        )
        await self.session.commit()

    async def members(
        self,
        team_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[TeamMembershipResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found")
        await self.permissions.require_permission(
            actor,
            "team_membership",
            department_id=row[0].department_id,
            team_id=team_id,
        )
        return [
            self._membership_response(membership, member)
            for membership, member in await self.teams.members(
                team_id, organisation_id
            )
        ]

    async def _department(self, department_id: UUID | None, organisation_id: UUID):
        if department_id is None:
            return None
        department = await self.departments.get_for_organisation(
            department_id, organisation_id
        )
        if not department:
            raise NotFoundError("Department not found in this organisation")
        return department

    async def _lock_organisation(self, organisation_id: UUID) -> None:
        if await self.session.scalar(
            select(Organisation.id)
            .where(Organisation.id == organisation_id)
            .with_for_update()
        ) is None:
            raise NotFoundError("Organisation not found")

    async def _audit(
        self,
        actor_id: UUID,
        organisation_id: UUID,
        action: AuditAction,
        entity_id: UUID,
        metadata: dict | None = None,
    ) -> None:
        await self.governance.add(
            AuditEvent(
                organisation_id=organisation_id,
                actor_id=actor_id,
                action=action.value,
                entity_type="team",
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )

    @staticmethod
    def _response(team: Team, department) -> TeamResponse:
        return TeamResponse.model_validate(
            {
                **team.__dict__,
                "department": DepartmentSummary.model_validate(department)
                if department
                else None,
            }
        )

    @staticmethod
    def _membership_response(
        membership: TeamMembership, member
    ) -> TeamMembershipResponse:
        return TeamMembershipResponse.model_validate(
            {**membership.__dict__, "user": UserSummary.model_validate(member)}
        )