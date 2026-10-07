from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.organisation import Organisation
from app.models.organisation_join_request import OrganisationJoinRequest
from app.models.organisation_owner import OrganisationOwner
from app.models.organisation_permission import OrganisationPermissionGrant
from app.models.team import Team, TeamStatus
from app.models.team_membership import TeamMembership
from app.models.user import User, UserRole
from app.repositories.user import UserRepository
from app.schemas.organisation_administration import (
    OrganisationCapability,
    OrganisationJoinRequestCreate,
    OrganisationJoinRequestDecision,
    OrganisationOwnerSummary,
    OrganisationPermissionCreate,
)
from app.services.permissions import PermissionService


class OrganisationAdministrationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.permissions = PermissionService(UserRepository(session))

    async def profile(self, organisation_id: UUID, user_id: UUID) -> dict:
        actor = await self.permissions.actor(user_id, organisation_id)
        organisation = await self.session.get(Organisation, organisation_id)
        department_name = None
        if actor.department_id is not None:
            department_name = await self.session.scalar(
                select(Department.name).where(
                    Department.id == actor.department_id,
                    Department.organisation_id == organisation_id,
                )
            )
        team_names = list(
            await self.session.scalars(
                select(Team.name)
                .join(
                    TeamMembership,
                    TeamMembership.team_id == Team.id,
                )
                .where(
                    TeamMembership.organisation_id == organisation_id,
                    TeamMembership.user_id == user_id,
                    Team.organisation_id == organisation_id,
                    Team.status == TeamStatus.ACTIVE,
                )
                .order_by(Team.name)
            )
        )
        is_owner = await self.permissions.is_owner(actor)
        grants = list(
            await self.session.scalars(
                select(OrganisationPermissionGrant).where(
                    OrganisationPermissionGrant.organisation_id == organisation_id,
                    OrganisationPermissionGrant.user_id == user_id,
                    OrganisationPermissionGrant.revoked_at.is_(None),
                )
            )
        )
        managed = {grant.permission for grant in grants}
        permission_scopes = [
            OrganisationCapability(
                permission=grant.permission,
                scope_type=grant.scope_type,
                scope_id=grant.scope_id,
            )
            for grant in grants
        ]
        if is_owner:
            managed.update(
                {"team_create", "team_membership", "review", "answer_approval"}
            )
            permission_scopes.extend(
                OrganisationCapability(
                    permission=permission,
                    scope_type="organisation",
                    scope_id=None,
                )
                for permission in (
                    "team_create",
                    "team_membership",
                    "review",
                    "answer_approval",
                )
            )
        assignment_managers = list(
            await self.session.scalars(
                select(User.display_name)
                .join(
                    OrganisationOwner,
                    OrganisationOwner.user_id == User.id,
                )
                .where(
                    OrganisationOwner.organisation_id == organisation_id,
                    User.status == "active",
                )
                .order_by(User.display_name)
            )
        )
        assignment_managers.extend(
            await self.session.scalars(
                select(User.display_name)
                .join(
                    OrganisationPermissionGrant,
                    OrganisationPermissionGrant.user_id == User.id,
                )
                .where(
                    OrganisationPermissionGrant.organisation_id == organisation_id,
                    OrganisationPermissionGrant.permission.in_(
                        ["legacy_admin", "team_membership"]
                    ),
                    OrganisationPermissionGrant.revoked_at.is_(None),
                    User.status == "active",
                )
                .distinct()
                .order_by(User.display_name)
            )
        )
        return {
            "organisation_id": organisation_id,
            "organisation_name": organisation.name if organisation else "",
            "user_id": user_id,
            "role": actor.role.value,
            "primary_department": department_name,
            "teams": team_names,
            "is_owner": is_owner,
            "permissions": sorted(managed),
            "permission_scopes": [
                item.model_dump(mode="json") for item in permission_scopes
            ],
            "assignment_managers": sorted(set(assignment_managers)),
        }

    async def list_owners(
        self, organisation_id: UUID, user_id: UUID
    ) -> list[OrganisationOwnerSummary]:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        result = await self.session.execute(
            select(OrganisationOwner, User)
            .join(User, User.id == OrganisationOwner.user_id)
            .where(OrganisationOwner.organisation_id == organisation_id)
            .order_by(User.display_name, User.id)
        )
        return [
            OrganisationOwnerSummary(
                user_id=user.id,
                display_name=user.display_name,
                email=user.email,
                active=user.status == "active",
            )
            for _, user in result.all()
        ]

    async def list_grants(self, organisation_id: UUID, user_id: UUID) -> list:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        result = await self.session.scalars(
            select(OrganisationPermissionGrant)
            .where(
                OrganisationPermissionGrant.organisation_id == organisation_id,
                OrganisationPermissionGrant.revoked_at.is_(None),
            )
            .order_by(
                OrganisationPermissionGrant.user_id,
                OrganisationPermissionGrant.permission,
                OrganisationPermissionGrant.scope_type,
            )
        )
        return list(result)

    async def grant(
        self,
        organisation_id: UUID,
        actor_id: UUID,
        data: OrganisationPermissionCreate,
    ) -> OrganisationPermissionGrant:
        actor = await self.permissions.actor(actor_id, organisation_id)
        if not await self.permissions.is_owner(actor):
            raise HTTPException(status_code=403, detail="Organisation owner required")
        target = await self._active_member(data.user_id, organisation_id)
        self._validate_scope_shape(data.scope_type, data.scope_id)
        if data.permission == "team_create" and data.scope_type == "team":
            raise HTTPException(
                status_code=422,
                detail="Team creation may be scoped to an organisation or department",
            )
        if data.scope_type == "department":
            await self._department(data.scope_id, organisation_id)
        elif data.scope_type == "team":
            await self._team(data.scope_id, organisation_id)
        existing = await self.session.scalar(
            select(OrganisationPermissionGrant).where(
                OrganisationPermissionGrant.organisation_id == organisation_id,
                OrganisationPermissionGrant.user_id == target.id,
                OrganisationPermissionGrant.permission == data.permission,
                OrganisationPermissionGrant.scope_type == data.scope_type,
                OrganisationPermissionGrant.scope_id == data.scope_id,
                OrganisationPermissionGrant.revoked_at.is_(None),
            )
        )
        if existing:
            return existing
        grant = OrganisationPermissionGrant(
            organisation_id=organisation_id,
            user_id=target.id,
            permission=data.permission,
            scope_type=data.scope_type,
            scope_id=data.scope_id,
            granted_by=actor.id,
        )
        self.session.add(grant)
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_PERMISSION_GRANTED,
            target.id,
            {
                "permission": data.permission,
                "scope_type": data.scope_type,
                "scope_id": str(data.scope_id) if data.scope_id else None,
                "outcome": "granted",
            },
        )
        await self.session.commit()
        await self.session.refresh(grant)
        return grant

    async def revoke_grant(
        self, organisation_id: UUID, actor_id: UUID, grant_id: UUID
    ) -> None:
        actor = await self.permissions.actor(actor_id, organisation_id)
        if not await self.permissions.is_owner(actor):
            raise HTTPException(status_code=403, detail="Organisation owner required")
        grant = await self.session.scalar(
            select(OrganisationPermissionGrant)
            .where(
                OrganisationPermissionGrant.id == grant_id,
                OrganisationPermissionGrant.organisation_id == organisation_id,
                OrganisationPermissionGrant.revoked_at.is_(None),
            )
            .with_for_update()
        )
        if grant is None:
            raise HTTPException(status_code=404, detail="Active permission not found")
        grant.revoked_at = datetime.now(UTC)
        grant.revoked_by = actor.id
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_PERMISSION_REVOKED,
            grant.user_id,
            {
                "permission": grant.permission,
                "scope_type": grant.scope_type,
                "scope_id": str(grant.scope_id) if grant.scope_id else None,
                "outcome": "revoked",
            },
        )
        await self.session.commit()

    async def appoint_admin(
        self, organisation_id: UUID, actor_id: UUID, target_id: UUID
    ) -> User:
        actor = await self.permissions.actor(actor_id, organisation_id)
        if not await self.permissions.is_owner(actor):
            raise HTTPException(status_code=403, detail="Organisation owner required")
        target = await self._active_member(target_id, organisation_id)
        if target.role != UserRole.ADMIN:
            old_role = target.role.value
            target.role = UserRole.ADMIN
            self._audit(
                organisation_id,
                actor.id,
                AuditAction.ORGANISATION_MEMBER_ROLE_CHANGED,
                target.id,
                {"old_role": old_role, "new_role": "admin", "outcome": "appointed"},
            )
            await self.session.commit()
            await self.session.refresh(target)
        return target

    async def appoint_owner(
        self, organisation_id: UUID, actor_id: UUID, target_id: UUID
    ) -> OrganisationOwner:
        actor = await self.permissions.actor(actor_id, organisation_id)
        if not await self.permissions.is_owner(actor):
            raise HTTPException(status_code=403, detail="Organisation owner required")
        target = await self.session.scalar(
            select(User)
            .where(
                User.id == target_id,
                User.organisation_id == organisation_id,
            )
            .with_for_update()
        )
        if target is None:
            raise HTTPException(status_code=404, detail="Organisation owner not found")
        existing = await self.session.scalar(
            select(OrganisationOwner).where(
                OrganisationOwner.organisation_id == organisation_id,
                OrganisationOwner.user_id == target.id,
            )
        )
        if existing:
            return existing
        owner = OrganisationOwner(
            organisation_id=organisation_id,
            user_id=target.id,
            appointed_by=actor.id,
        )
        self.session.add(owner)
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_OWNER_APPOINTED,
            target.id,
            {"target_user_id": str(target.id), "outcome": "appointed"},
        )
        await self.session.commit()
        await self.session.refresh(owner)
        return owner

    async def revoke_owner(
        self, organisation_id: UUID, actor_id: UUID, target_id: UUID
    ) -> None:
        actor = await self.permissions.actor(actor_id, organisation_id)
        if not await self.permissions.is_owner(actor):
            raise HTTPException(status_code=403, detail="Organisation owner required")
        target_owner = await self.session.scalar(
            select(OrganisationOwner)
            .where(
                OrganisationOwner.organisation_id == organisation_id,
                OrganisationOwner.user_id == target_id,
            )
            .with_for_update()
        )
        if target_owner is None:
            raise HTTPException(status_code=404, detail="Organisation owner not found")
        target = await self._active_member(target_id, organisation_id)
        if target.status == "active":
            active_owner_count = await self.session.scalar(
                select(func.count(OrganisationOwner.id))
                .join(User, User.id == OrganisationOwner.user_id)
                .where(
                    OrganisationOwner.organisation_id == organisation_id,
                    User.status == "active",
                )
            )
            if active_owner_count <= 1:
                raise HTTPException(
                    status_code=409,
                    detail="The last active organisation owner cannot be removed",
                )
        await self.session.delete(target_owner)
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_OWNER_REVOKED,
            target.id,
            {"target_user_id": str(target.id), "outcome": "revoked"},
        )
        await self.session.commit()

    async def request_membership(
        self, organisation_id: UUID, user_id: UUID, data: OrganisationJoinRequestCreate
    ) -> OrganisationJoinRequest:
        actor = await self.permissions.actor(user_id, organisation_id)
        if data.request_type == "team":
            target = await self._team(data.target_id, organisation_id)
            if target.status != TeamStatus.ACTIVE:
                raise HTTPException(status_code=404, detail="Active team not found")
            exists = await self.session.scalar(
                select(TeamMembership.id).where(
                    TeamMembership.organisation_id == organisation_id,
                    TeamMembership.team_id == target.id,
                    TeamMembership.user_id == actor.id,
                )
            )
            if exists:
                raise HTTPException(status_code=409, detail="Already a team member")
        else:
            target = await self._department(data.target_id, organisation_id)
            if actor.department_id == target.id:
                raise HTTPException(
                    status_code=409, detail="Already in this department"
                )
        existing = await self.session.scalar(
            select(OrganisationJoinRequest).where(
                OrganisationJoinRequest.organisation_id == organisation_id,
                OrganisationJoinRequest.requester_id == actor.id,
                OrganisationJoinRequest.request_type == data.request_type,
                OrganisationJoinRequest.target_id == data.target_id,
                OrganisationJoinRequest.status == "pending",
            )
        )
        if existing:
            return existing
        request = OrganisationJoinRequest(
            organisation_id=organisation_id,
            requester_id=actor.id,
            request_type=data.request_type,
            target_id=data.target_id,
            reason=data.reason,
        )
        self.session.add(request)
        await self.session.flush()
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_JOIN_REQUESTED,
            request.id,
            {
                "request_type": data.request_type,
                "target_id": str(data.target_id),
                "scope_type": data.request_type,
                "outcome": "pending",
            },
        )
        try:
            await self.session.commit()
        except IntegrityError:
            await self.session.rollback()
            request = await self.session.scalar(
                select(OrganisationJoinRequest).where(
                    OrganisationJoinRequest.organisation_id == organisation_id,
                    OrganisationJoinRequest.requester_id == actor.id,
                    OrganisationJoinRequest.request_type == data.request_type,
                    OrganisationJoinRequest.target_id == data.target_id,
                    OrganisationJoinRequest.status == "pending",
                )
            )
            if request is None:
                raise HTTPException(status_code=409, detail="Request retry conflicted")
            return request
        await self.session.refresh(request)
        return request

    async def list_requests(
        self, organisation_id: UUID, user_id: UUID, *, pending: bool = True
    ) -> list[OrganisationJoinRequest]:
        actor = await self.permissions.actor(user_id, organisation_id)
        result = await self.session.scalars(
            select(OrganisationJoinRequest)
            .where(
                OrganisationJoinRequest.organisation_id == organisation_id,
                *(
                    [OrganisationJoinRequest.status == "pending"]
                    if pending
                    else [OrganisationJoinRequest.requester_id == actor.id]
                ),
            )
            .order_by(OrganisationJoinRequest.created_at)
        )
        if pending:
            requests = list(result)
            filtered_requests = []
            for request in requests:
                department_id, team_id = await self._request_scope(request)
                required = (
                    "team_membership" if request.request_type == "team" else "review"
                )
                if not await self.permissions.has_permission(
                    actor,
                    required,
                    department_id=department_id,
                    team_id=team_id,
                ):
                    continue
                filtered_requests.append(request)
            return filtered_requests
        return list(result)

    async def decide_request(
        self,
        organisation_id: UUID,
        actor_id: UUID,
        request_id: UUID,
        data: OrganisationJoinRequestDecision,
    ) -> OrganisationJoinRequest:
        actor = await self.permissions.actor(actor_id, organisation_id)
        request = await self.session.scalar(
            select(OrganisationJoinRequest)
            .where(
                OrganisationJoinRequest.id == request_id,
                OrganisationJoinRequest.organisation_id == organisation_id,
            )
            .with_for_update()
        )
        if request is None:
            raise HTTPException(status_code=404, detail="Join request not found")
        if request.status != "pending":
            raise HTTPException(
                status_code=409, detail="Join request was already decided"
            )
        requester = await self.session.scalar(
            select(User)
            .where(
                User.id == request.requester_id,
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .with_for_update()
        )
        if requester is None:
            raise HTTPException(status_code=404, detail="Active requester not found")
        department_id, team_id = await self._request_scope(request)
        permission = "team_membership" if request.request_type == "team" else "review"
        await self.permissions.require_permission(
            actor,
            permission,
            department_id=department_id,
            team_id=team_id,
        )
        if data.decision == "approve" and actor.id == requester.id:
            raise HTTPException(
                status_code=403, detail="You cannot approve your own join request"
            )
        if data.decision == "approve":
            if request.request_type == "team":
                team = await self._team(request.target_id, organisation_id)
                if team.status != TeamStatus.ACTIVE:
                    raise HTTPException(
                        status_code=409, detail="Team is no longer active"
                    )
                membership = await self.session.scalar(
                    select(TeamMembership).where(
                        TeamMembership.organisation_id == organisation_id,
                        TeamMembership.team_id == team.id,
                        TeamMembership.user_id == requester.id,
                    )
                )
                if membership is not None:
                    raise HTTPException(
                        status_code=409, detail="User is already a team member"
                    )
                self.session.add(
                    TeamMembership(
                        organisation_id=organisation_id,
                        team_id=team.id,
                        user_id=requester.id,
                    )
                )
                self._audit(
                    organisation_id,
                    actor.id,
                    AuditAction.TEAM_MEMBER_ADDED,
                    request.id,
                    {
                        "team_id": str(team.id),
                        "user_id": str(requester.id),
                        "source": "approved_join_request",
                        "outcome": "added",
                    },
                )
            else:
                department = await self._department(request.target_id, organisation_id)
                previous_department_id = requester.department_id
                requester.department_id = department.id
                self._audit(
                    organisation_id,
                    actor.id,
                    AuditAction.USER_PRIMARY_DEPARTMENT_CHANGED,
                    requester.id,
                    {
                        "old_department_id": (
                            str(previous_department_id)
                            if previous_department_id
                            else None
                        ),
                        "new_department_id": str(department.id),
                        "source": "approved_join_request",
                        "outcome": "changed",
                    },
                )
        request.status = "approved" if data.decision == "approve" else "declined"
        request.reviewed_by = actor.id
        request.reviewer_note = data.reviewer_note
        request.reviewed_at = datetime.now(UTC)
        self._audit(
            organisation_id,
            actor.id,
            AuditAction.ORGANISATION_JOIN_REQUEST_DECIDED,
            request.id,
            {
                "request_type": request.request_type,
                "target_id": str(request.target_id),
                "target_user_id": str(requester.id),
                "scope_type": request.request_type,
                "outcome": request.status,
            },
        )
        await self.session.commit()
        await self.session.refresh(request)
        return request

    async def _request_scope(
        self, request: OrganisationJoinRequest
    ) -> tuple[UUID | None, UUID | None]:
        if request.request_type == "team":
            team = await self._team(request.target_id, request.organisation_id)
            return team.department_id, team.id
        department = await self._department(request.target_id, request.organisation_id)
        return department.id, None

    async def _active_member(self, user_id: UUID, organisation_id: UUID) -> User:
        user = await self.session.scalar(
            select(User)
            .where(
                User.id == user_id,
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .with_for_update()
        )
        if user is None:
            raise HTTPException(status_code=404, detail="Active member not found")
        return user

    async def _department(
        self, department_id: UUID | None, organisation_id: UUID
    ) -> Department:
        department = await self.session.scalar(
            select(Department).where(
                Department.id == department_id,
                Department.organisation_id == organisation_id,
            )
        )
        if department is None:
            raise HTTPException(status_code=404, detail="Department not found")
        return department

    async def _team(self, team_id: UUID | None, organisation_id: UUID) -> Team:
        team = await self.session.scalar(
            select(Team).where(
                Team.id == team_id,
                Team.organisation_id == organisation_id,
            )
        )
        if team is None:
            raise HTTPException(status_code=404, detail="Team not found")
        return team

    @staticmethod
    def _validate_scope_shape(scope_type: str, scope_id: UUID | None) -> None:
        if (scope_type == "organisation") != (scope_id is None):
            raise HTTPException(
                status_code=422,
                detail="Organisation scope has no ID; department/team scope requires an ID",
            )

    def _audit(
        self,
        organisation_id: UUID,
        actor_id: UUID,
        action: AuditAction,
        entity_id: UUID,
        metadata: dict,
    ) -> None:
        self.session.add(
            AuditEvent(
                organisation_id=organisation_id,
                actor_id=actor_id,
                action=action.value,
                entity_type="organisation_administration",
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )
