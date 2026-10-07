import asyncio
import os
from uuid import uuid4

import pytest
import pytest_asyncio
from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.exceptions import NotFoundError, PermissionDeniedError
from app.models import Base
from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.organisation import Organisation
from app.models.organisation_join_request import OrganisationJoinRequest
from app.models.organisation_owner import OrganisationOwner
from app.models.organisation_permission import OrganisationPermissionGrant
from app.models.team import Team
from app.models.team_membership import TeamMembership
from app.models.user import User
from app.repositories.user import UserRepository
from app.schemas.organisation_administration import (
    OrganisationJoinRequestCreate,
    OrganisationJoinRequestDecision,
)
from app.schemas.organisation_member import OrganisationMemberUpdate
from app.schemas.team import TeamMemberCreate
from app.services.organisation_administration import (
    OrganisationAdministrationService,
)
from app.services.organisation_member import OrganisationMemberService
from app.services.permissions import PermissionService
from app.services.team import TeamService


@pytest_asyncio.fixture
async def postgres_sessions():
    url = os.environ.get("ORGANISATION_TEST_POSTGRES_URL")
    if not url:
        pytest.skip("Set ORGANISATION_TEST_POSTGRES_URL to run PostgreSQL races.")
    schema = f"org_admin_test_{uuid4().hex}"
    admin_engine = create_async_engine(url)
    async with admin_engine.begin() as connection:
        await connection.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_async_engine(
        url,
        connect_args={"server_settings": {"search_path": f"{schema},public"}},
    )
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        yield async_sessionmaker(engine, expire_on_commit=False)
    finally:
        await engine.dispose()
        async with admin_engine.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        await admin_engine.dispose()


async def seed_postgres(session_factory):
    async with session_factory() as session:
        organisation = Organisation(name="Race Test", slug=f"race-{uuid4().hex}")
        other_organisation = Organisation(
            name="Other Race Test", slug=f"other-race-{uuid4().hex}"
        )
        session.add_all([organisation, other_organisation])
        await session.flush()
        department = Department(
            organisation_id=organisation.id,
            name="Operations",
        )
        session.add(department)
        await session.flush()
        team = Team(
            organisation_id=organisation.id,
            department_id=department.id,
            name="Operations Team",
        )
        owner_a = User(
            organisation_id=organisation.id,
            email=f"a-{uuid4().hex}@test.invalid",
            display_name="Owner A",
        )
        owner_b = User(
            organisation_id=organisation.id,
            email=f"b-{uuid4().hex}@test.invalid",
            display_name="Owner B",
        )
        manager = User(
            organisation_id=organisation.id,
            email=f"manager-{uuid4().hex}@test.invalid",
            display_name="Team manager",
        )
        requester = User(
            organisation_id=organisation.id,
            email=f"requester-{uuid4().hex}@test.invalid",
            display_name="Requester",
        )
        member = User(
            organisation_id=organisation.id,
            email=f"member-{uuid4().hex}@test.invalid",
            display_name="Member",
        )
        outsider = User(
            organisation_id=other_organisation.id,
            email=f"outside-{uuid4().hex}@test.invalid",
            display_name="Outsider",
        )
        session.add_all([team, owner_a, owner_b, manager, requester, member, outsider])
        await session.flush()
        session.add_all(
            [
                OrganisationOwner(
                    organisation_id=organisation.id,
                    user_id=owner_a.id,
                    appointed_by=None,
                ),
                OrganisationOwner(
                    organisation_id=organisation.id,
                    user_id=owner_b.id,
                    appointed_by=owner_a.id,
                ),
            ]
        )
        session.add(
            OrganisationPermissionGrant(
                organisation_id=organisation.id,
                user_id=manager.id,
                permission="team_membership",
                scope_type="team",
                scope_id=team.id,
                granted_by=owner_a.id,
            )
        )
        await session.commit()
        return {
            "organisation_id": organisation.id,
            "department_id": department.id,
            "team_id": team.id,
            "owner_a": owner_a.id,
            "owner_b": owner_b.id,
            "manager": manager.id,
            "requester": requester.id,
            "member": member.id,
            "outsider": outsider.id,
        }


@pytest.mark.asyncio
async def test_postgres_concurrent_owner_removal_preserves_active_owner(
    postgres_sessions,
):
    ids = await seed_postgres(postgres_sessions)

    async def revoke(actor_id, target_id):
        async with postgres_sessions() as session:
            try:
                await OrganisationAdministrationService(session).revoke_owner(
                    ids["organisation_id"], actor_id, target_id
                )
                return 204
            except (HTTPException, PermissionDeniedError) as error:
                await session.rollback()
                return getattr(error, "status_code", 403)

    outcomes = await asyncio.gather(
        revoke(ids["owner_a"], ids["owner_b"]),
        revoke(ids["owner_b"], ids["owner_a"]),
    )
    assert sorted(outcomes) == [204, 403]
    async with postgres_sessions() as session:
        active_owners = await session.scalar(
            select(func.count(OrganisationOwner.id))
            .join(User, User.id == OrganisationOwner.user_id)
            .where(
                OrganisationOwner.organisation_id == ids["organisation_id"],
                User.status == "active",
            )
        )
        assert active_owners == 1


@pytest.mark.asyncio
async def test_postgres_concurrent_owner_revocation_and_deactivation_preserve_owner(
    postgres_sessions,
):
    ids = await seed_postgres(postgres_sessions)

    async def revoke(actor_id, target_id):
        async with postgres_sessions() as session:
            try:
                await OrganisationAdministrationService(session).revoke_owner(
                    ids["organisation_id"], actor_id, target_id
                )
                return "revoked"
            except (HTTPException, PermissionDeniedError, NotFoundError):
                await session.rollback()
                return "denied"

    async def deactivate(actor_id, target_id):
        async with postgres_sessions() as session:
            try:
                permissions = PermissionService(UserRepository(session))
                actor = await permissions.actor(actor_id, ids["organisation_id"])
                if not await permissions.is_owner(actor):
                    raise PermissionDeniedError("Organisation owner required")
                await OrganisationMemberService(session).update_member(
                    organisation_id=ids["organisation_id"],
                    actor_id=actor_id,
                    member_id=target_id,
                    update=OrganisationMemberUpdate(status="inactive"),
                )
                return "deactivated"
            except (HTTPException, PermissionDeniedError, NotFoundError):
                await session.rollback()
                return "denied"

    outcomes = await asyncio.gather(
        revoke(ids["owner_a"], ids["owner_b"]),
        deactivate(ids["owner_b"], ids["owner_a"]),
    )
    assert set(outcomes).issubset({"denied", "deactivated", "revoked"})
    assert any(outcome != "denied" for outcome in outcomes)
    async with postgres_sessions() as session:
        active_owners = await session.scalar(
            select(func.count(OrganisationOwner.id))
            .join(User, User.id == OrganisationOwner.user_id)
            .where(
                OrganisationOwner.organisation_id == ids["organisation_id"],
                User.status == "active",
            )
        )
        assert active_owners == 1


@pytest.mark.asyncio
async def test_postgres_duplicate_requests_and_concurrent_decisions_are_serialized(
    postgres_sessions,
):
    ids = await seed_postgres(postgres_sessions)

    async def request_membership():
        async with postgres_sessions() as session:
            request = await OrganisationAdministrationService(
                session
            ).request_membership(
                ids["organisation_id"],
                ids["requester"],
                OrganisationJoinRequestCreate(
                    request_type="team",
                    target_id=ids["team_id"],
                    reason="Concurrent request test",
                ),
            )
            return request.id

    request_ids = await asyncio.gather(
        request_membership(),
        request_membership(),
    )
    assert request_ids[0] == request_ids[1]
    async with postgres_sessions() as session:
        assert (
            await session.scalar(
                select(func.count(OrganisationJoinRequest.id)).where(
                    OrganisationJoinRequest.organisation_id == ids["organisation_id"],
                    OrganisationJoinRequest.requester_id == ids["requester"],
                    OrganisationJoinRequest.status == "pending",
                )
            )
            == 1
        )
        request_id = request_ids[0]

    async def decide(decision):
        async with postgres_sessions() as session:
            try:
                await OrganisationAdministrationService(session).decide_request(
                    ids["organisation_id"],
                    ids["manager"],
                    request_id,
                    OrganisationJoinRequestDecision(decision=decision),
                )
                return 200
            except (HTTPException, PermissionDeniedError) as error:
                await session.rollback()
                return getattr(error, "status_code", 403)

    outcomes = await asyncio.gather(decide("approve"), decide("decline"))
    assert sorted(outcomes) == [200, 409]
    async with postgres_sessions() as session:
        memberships = await session.scalar(
            select(func.count(TeamMembership.id)).where(
                TeamMembership.organisation_id == ids["organisation_id"],
                TeamMembership.team_id == ids["team_id"],
                TeamMembership.user_id == ids["requester"],
            )
        )
        request = await session.get(OrganisationJoinRequest, request_id)
        assert memberships == 1
        assert request is not None and request.status == "approved"


@pytest.mark.asyncio
async def test_postgres_grant_revocation_serializes_against_team_action(
    postgres_sessions,
):
    ids = await seed_postgres(postgres_sessions)
    async with postgres_sessions() as session:
        grant_id = await session.scalar(
            select(OrganisationPermissionGrant.id).where(
                OrganisationPermissionGrant.organisation_id == ids["organisation_id"],
                OrganisationPermissionGrant.user_id == ids["manager"],
                OrganisationPermissionGrant.permission == "team_membership",
            )
        )
        assert grant_id is not None

    async def revoke():
        async with postgres_sessions() as session:
            await OrganisationAdministrationService(session).revoke_grant(
                ids["organisation_id"], ids["owner_a"], grant_id
            )
        return 204

    async def add_member():
        async with postgres_sessions() as session:
            try:
                await TeamService(session).add_member(
                    ids["team_id"],
                    ids["organisation_id"],
                    ids["manager"],
                    TeamMemberCreate(user_id=ids["member"]),
                )
                return 201
            except (HTTPException, PermissionDeniedError) as error:
                await session.rollback()
                return getattr(error, "status_code", 403)

    outcomes = await asyncio.gather(revoke(), add_member())
    assert outcomes[0] == 204
    assert outcomes[1] in (201, 403)
    async with postgres_sessions() as session:
        grant = await session.get(OrganisationPermissionGrant, grant_id)
        membership = await session.scalar(
            select(TeamMembership).where(
                TeamMembership.organisation_id == ids["organisation_id"],
                TeamMembership.team_id == ids["team_id"],
                TeamMembership.user_id == ids["member"],
            )
        )
        assert grant is not None and grant.revoked_at is not None
        if outcomes[1] == 201:
            assert membership is not None
            events = list(
                await session.scalars(
                    select(AuditEvent).where(
                        AuditEvent.organisation_id == ids["organisation_id"],
                        AuditEvent.action.in_(
                            [
                                AuditAction.TEAM_MEMBER_ADDED.value,
                                AuditAction.ORGANISATION_PERMISSION_REVOKED.value,
                            ]
                        ),
                    )
                )
            )
            action_event = next(
                event
                for event in events
                if event.action == AuditAction.TEAM_MEMBER_ADDED.value
            )
            revoke_event = next(
                event
                for event in events
                if event.action == AuditAction.ORGANISATION_PERMISSION_REVOKED.value
            )
            assert action_event.created_at <= revoke_event.created_at
