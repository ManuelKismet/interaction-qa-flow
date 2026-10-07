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
    async def run_order(first_decision: str) -> None:
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
                        reason=f"Concurrent {first_decision}-first test",
                    ),
                )
                return request.id

        request_ids = await asyncio.gather(
            request_membership(),
            request_membership(),
        )
        assert request_ids[0] == request_ids[1]
        request_id = request_ids[0]
        async with postgres_sessions() as session:
            pending_count = await session.scalar(
                select(func.count(OrganisationJoinRequest.id)).where(
                    OrganisationJoinRequest.organisation_id == ids["organisation_id"],
                    OrganisationJoinRequest.requester_id == ids["requester"],
                    OrganisationJoinRequest.status == "pending",
                )
            )
            assert pending_count == 1

        second_decision = "decline" if first_decision == "approve" else "approve"
        app_names = {
            decision: f"join_{decision}_{uuid4().hex}"
            for decision in (first_decision, second_decision)
        }

        async def decide(decision: str) -> int:
            async with postgres_sessions() as session:
                try:
                    await session.execute(
                        text("SELECT set_config('application_name', :name, false)"),
                        {"name": app_names[decision]},
                    )
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

        async def wait_for_lock_waiter(application_name: str) -> None:
            async def is_waiting() -> bool:
                async with postgres_sessions() as session:
                    return bool(
                        await session.scalar(
                            text(
                                """
                                SELECT EXISTS (
                                    SELECT 1
                                    FROM pg_stat_activity
                                    WHERE application_name = :name
                                      AND wait_event_type = 'Lock'
                                )
                                """
                            ),
                            {"name": application_name},
                        )
                    )

            async def poll() -> None:
                while not await is_waiting():
                    await asyncio.sleep(0.01)

            await asyncio.wait_for(poll(), timeout=5)

        async with postgres_sessions() as lock_session:
            await lock_session.begin()
            await lock_session.scalar(
                select(Organisation.id)
                .where(Organisation.id == ids["organisation_id"])
                .with_for_update()
            )
            first_task = asyncio.create_task(decide(first_decision))
            second_task = None
            try:
                await wait_for_lock_waiter(app_names[first_decision])
                second_task = asyncio.create_task(decide(second_decision))
                await wait_for_lock_waiter(app_names[second_decision])
                await lock_session.commit()
                outcomes = await asyncio.wait_for(
                    asyncio.gather(first_task, second_task),
                    timeout=10,
                )
            finally:
                if lock_session.in_transaction():
                    await lock_session.rollback()
                tasks = [first_task]
                if second_task is not None:
                    tasks.append(second_task)
                await asyncio.gather(*tasks, return_exceptions=True)

        assert outcomes == [200, 409]
        async with postgres_sessions() as session:
            membership_count = await session.scalar(
                select(func.count(TeamMembership.id)).where(
                    TeamMembership.organisation_id == ids["organisation_id"],
                    TeamMembership.team_id == ids["team_id"],
                    TeamMembership.user_id == ids["requester"],
                )
            )
            request = await session.get(OrganisationJoinRequest, request_id)
            assert request is not None
            assert request.status == (
                "approved" if first_decision == "approve" else "declined"
            )
            assert request.reviewed_by == ids["manager"]
            assert membership_count == (1 if first_decision == "approve" else 0)

            decision_events = list(
                await session.scalars(
                    select(AuditEvent).where(
                        AuditEvent.organisation_id == ids["organisation_id"],
                        AuditEvent.action
                        == AuditAction.ORGANISATION_JOIN_REQUEST_DECIDED.value,
                        AuditEvent.entity_id == request_id,
                    )
                )
            )
            assert len(decision_events) == 1
            assert decision_events[0].actor_id == ids["manager"]
            assert decision_events[0].event_metadata["outcome"] == request.status

            member_add_events = list(
                await session.scalars(
                    select(AuditEvent).where(
                        AuditEvent.organisation_id == ids["organisation_id"],
                        AuditEvent.action == AuditAction.TEAM_MEMBER_ADDED.value,
                        AuditEvent.entity_id == request_id,
                    )
                )
            )
            assert len(member_add_events) == (
                1 if first_decision == "approve" else 0
            )

    await run_order("approve")
    await run_order("decline")


@pytest.mark.asyncio
async def test_postgres_self_approval_race_allows_only_separate_reviewer(
    postgres_sessions,
):
    ids = await seed_postgres(postgres_sessions)
    async with postgres_sessions() as session:
        session.add(
            OrganisationPermissionGrant(
                organisation_id=ids["organisation_id"],
                user_id=ids["requester"],
                permission="review",
                scope_type="department",
                scope_id=ids["department_id"],
                granted_by=ids["owner_a"],
            )
        )
        await session.commit()
        request = await OrganisationAdministrationService(
            session
        ).request_membership(
            ids["organisation_id"],
            ids["requester"],
            OrganisationJoinRequestCreate(
                request_type="department",
                target_id=ids["department_id"],
                reason="Requester's own department change",
            ),
        )
        request_id = request.id

    async def decide(actor_id):
        async with postgres_sessions() as session:
            try:
                await OrganisationAdministrationService(session).decide_request(
                    ids["organisation_id"],
                    actor_id,
                    request_id,
                    OrganisationJoinRequestDecision(decision="approve"),
                )
                return 200
            except (HTTPException, PermissionDeniedError) as error:
                await session.rollback()
                return getattr(error, "status_code", 403)

    outcomes = await asyncio.gather(
        decide(ids["requester"]),
        decide(ids["owner_a"]),
    )
    assert sorted(outcomes) == [200, 403]
    async with postgres_sessions() as session:
        requester = await session.get(User, ids["requester"])
        request = await session.get(OrganisationJoinRequest, request_id)
        assert requester is not None
        assert requester.department_id == ids["department_id"]
        assert request is not None
        assert request.status == "approved"
        assert request.reviewed_by == ids["owner_a"]


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
