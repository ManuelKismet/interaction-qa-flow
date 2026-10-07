from uuid import UUID

import pytest
from sqlalchemy import select

from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.organisation import Organisation
from app.models.organisation_join_request import OrganisationJoinRequest
from app.models.organisation_owner import OrganisationOwner
from app.models.team import Team
from app.models.team_membership import TeamMembership
from app.models.user import User, UserRole


def headers(ids, user="owner", organisation="organisation"):
    return {
        "X-Organisation-ID": str(ids[organisation]),
        "X-User-ID": str(ids[user]),
    }


async def seed_administration(session_factory):
    async with session_factory() as session:
        organisation = Organisation(name="Administration", slug="administration")
        other_organisation = Organisation(
            name="Other administration", slug="other-administration"
        )
        session.add_all([organisation, other_organisation])
        await session.flush()
        department = Department(
            organisation_id=organisation.id,
            name="People",
        )
        other_department = Department(
            organisation_id=organisation.id,
            name="Finance",
        )
        foreign_department = Department(
            organisation_id=other_organisation.id,
            name="Foreign",
        )
        session.add_all([department, other_department, foreign_department])
        await session.flush()
        team = Team(
            organisation_id=organisation.id,
            department_id=department.id,
            name="People operations",
        )
        owner = User(
            organisation_id=organisation.id,
            email="owner@administration.test",
            display_name="Owner",
            role=UserRole.EMPLOYEE,
        )
        admin_title_only = User(
            organisation_id=organisation.id,
            email="title-only@administration.test",
            display_name="Title only",
            role=UserRole.ADMIN,
        )
        manager = User(
            organisation_id=organisation.id,
            email="manager@administration.test",
            display_name="Manager",
        )
        requester = User(
            organisation_id=organisation.id,
            email="requester@administration.test",
            display_name="Requester",
        )
        outsider = User(
            organisation_id=other_organisation.id,
            email="outsider@administration.test",
            display_name="Outsider",
        )
        session.add_all([team, owner, admin_title_only, manager, requester, outsider])
        await session.flush()
        session.add(
            OrganisationOwner(
                organisation_id=organisation.id,
                user_id=owner.id,
                appointed_by=None,
            )
        )
        await session.commit()
        return {
            "organisation": organisation.id,
            "other_organisation": other_organisation.id,
            "department": department.id,
            "other_department": other_department.id,
            "foreign_department": foreign_department.id,
            "team": team.id,
            "owner": owner.id,
            "admin_title_only": admin_title_only.id,
            "manager": manager.id,
            "requester": requester.id,
            "outsider": outsider.id,
        }


@pytest.mark.asyncio
async def test_owner_grants_scoped_capabilities_and_admin_title_is_not_authority(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_administration(session_factory)

    role_only = await client.get(
        "/api/v1/organisation/permissions",
        headers=headers(ids, "admin_title_only"),
    )
    assert role_only.status_code == 403
    denied_team = await client.post(
        "/api/v1/teams",
        headers=headers(ids, "admin_title_only"),
        json={"name": "Unauthorised", "department_id": str(ids["department"])},
    )
    assert denied_team.status_code == 403

    create_grant = await client.post(
        "/api/v1/organisation/permissions",
        headers=headers(ids),
        json={
            "user_id": str(ids["manager"]),
            "permission": "team_create",
            "scope_type": "department",
            "scope_id": str(ids["department"]),
        },
    )
    assert create_grant.status_code == 201
    allowed_team = await client.post(
        "/api/v1/teams",
        headers=headers(ids, "manager"),
        json={"name": "People help", "department_id": str(ids["department"])},
    )
    assert allowed_team.status_code == 201
    denied_other_department = await client.post(
        "/api/v1/teams",
        headers=headers(ids, "manager"),
        json={"name": "Finance help", "department_id": str(ids["other_department"])},
    )
    assert denied_other_department.status_code == 403

    appointed = await client.post(
        f"/api/v1/organisation/admins/{ids['manager']}",
        headers=headers(ids),
    )
    assert appointed.status_code == 200
    assert appointed.json()["role"] == "admin"
    assert (
        await client.post(
            "/api/v1/teams",
            headers=headers(ids, "manager"),
            json={"name": "Admin is not permission", "department_id": None},
        )
    ).status_code == 403
    denied_audit = await client.get(
        "/api/v1/audit-events",
        headers=headers(ids, "admin_title_only"),
    )
    assert denied_audit.status_code == 403
    owner_audit = await client.get("/api/v1/audit-events", headers=headers(ids))
    assert owner_audit.status_code == 200
    assert any(
        item["action"] == AuditAction.ORGANISATION_PERMISSION_GRANTED.value
        and item["actor_id"] == str(ids["owner"])
        for item in owner_audit.json()
    )

    async with session_factory() as session:
        audit = list(
            await session.scalars(
                select(AuditEvent).where(
                    AuditEvent.action
                    == AuditAction.ORGANISATION_PERMISSION_GRANTED.value
                )
            )
        )
        assert len(audit) == 1
        assert audit[0].actor_id == ids["owner"]
        assert audit[0].entity_id == ids["manager"]
        assert audit[0].event_metadata == {
            "permission": "team_create",
            "scope_type": "department",
            "scope_id": str(ids["department"]),
            "outcome": "granted",
        }


@pytest.mark.asyncio
async def test_team_join_request_is_pending_until_scoped_manager_approves(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_administration(session_factory)
    grant = await client.post(
        "/api/v1/organisation/permissions",
        headers=headers(ids),
        json={
            "user_id": str(ids["manager"]),
            "permission": "team_membership",
            "scope_type": "team",
            "scope_id": str(ids["team"]),
        },
    )
    assert grant.status_code == 201
    available_members = await client.get(
        "/api/v1/auth/members",
        headers=headers(ids, "manager"),
    )
    assert available_members.status_code == 200
    assert {member["id"] for member in available_members.json()} == {
        str(ids["owner"]),
        str(ids["admin_title_only"]),
        str(ids["manager"]),
        str(ids["requester"]),
    }

    request_data = {
        "request_type": "team",
        "target_id": str(ids["team"]),
        "reason": "I support the team.",
    }
    first = await client.post(
        "/api/v1/organisation/join-requests",
        headers=headers(ids, "requester"),
        json=request_data,
    )
    retry = await client.post(
        "/api/v1/organisation/join-requests",
        headers=headers(ids, "requester"),
        json=request_data,
    )
    assert first.status_code == 201
    assert retry.status_code == 201
    assert retry.json()["id"] == first.json()["id"]

    pending = await client.get(
        f"/api/v1/teams/{ids['team']}/members",
        headers=headers(ids, "requester"),
    )
    assert pending.status_code == 403
    requests = await client.get(
        "/api/v1/organisation/join-requests",
        headers=headers(ids, "manager"),
    )
    assert [item["id"] for item in requests.json()] == [first.json()["id"]]
    decision = await client.post(
        f"/api/v1/organisation/join-requests/{first.json()['id']}/decision",
        headers=headers(ids, "manager"),
        json={"decision": "approve"},
    )
    assert decision.status_code == 200
    assert decision.json()["status"] == "approved"
    stale_decision = await client.post(
        f"/api/v1/organisation/join-requests/{first.json()['id']}/decision",
        headers=headers(ids, "manager"),
        json={"decision": "decline"},
    )
    assert stale_decision.status_code == 409

    async with session_factory() as session:
        memberships = list(
            await session.scalars(
                select(TeamMembership).where(
                    TeamMembership.organisation_id == ids["organisation"],
                    TeamMembership.team_id == ids["team"],
                    TeamMembership.user_id == ids["requester"],
                )
            )
        )
        request_row = await session.get(
            OrganisationJoinRequest, UUID(first.json()["id"])
        )
        assert len(memberships) == 1
        assert request_row is not None
        assert request_row.reviewed_by == ids["manager"]


@pytest.mark.asyncio
async def test_join_requests_and_team_membership_reject_foreign_tenant_ids(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_administration(session_factory)
    await client.post(
        "/api/v1/organisation/permissions",
        headers=headers(ids),
        json={
            "user_id": str(ids["manager"]),
            "permission": "team_membership",
            "scope_type": "team",
            "scope_id": str(ids["team"]),
        },
    )
    cross_tenant_member = await client.post(
        f"/api/v1/teams/{ids['team']}/members",
        headers=headers(ids, "manager"),
        json={"user_id": str(ids["outsider"])},
    )
    assert cross_tenant_member.status_code == 404
    cross_tenant_department = await client.post(
        "/api/v1/organisation/join-requests",
        headers=headers(ids, "requester"),
        json={
            "request_type": "department",
            "target_id": str(ids["foreign_department"]),
        },
    )
    assert cross_tenant_department.status_code == 404
    async with session_factory() as session:
        assert await session.scalar(select(OrganisationJoinRequest.id)) is None


@pytest.mark.asyncio
async def test_department_change_request_requires_scoped_review_approval(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_administration(session_factory)
    grant = await client.post(
        "/api/v1/organisation/permissions",
        headers=headers(ids),
        json={
            "user_id": str(ids["manager"]),
            "permission": "review",
            "scope_type": "department",
            "scope_id": str(ids["department"]),
        },
    )
    assert grant.status_code == 201
    request = await client.post(
        "/api/v1/organisation/join-requests",
        headers=headers(ids, "requester"),
        json={
            "request_type": "department",
            "target_id": str(ids["department"]),
            "reason": "Please move me to People.",
        },
    )
    assert request.status_code == 201
    async with session_factory() as session:
        requester = await session.get(User, ids["requester"])
        assert requester is not None
        assert requester.department_id is None
    denied = await client.post(
        f"/api/v1/organisation/join-requests/{request.json()['id']}/decision",
        headers=headers(ids, "admin_title_only"),
        json={"decision": "approve"},
    )
    assert denied.status_code == 403
    approved = await client.post(
        f"/api/v1/organisation/join-requests/{request.json()['id']}/decision",
        headers=headers(ids, "manager"),
        json={"decision": "approve"},
    )
    assert approved.status_code == 200
    async with session_factory() as session:
        requester = await session.get(User, ids["requester"])
        assert requester is not None
        assert requester.department_id == ids["department"]


@pytest.mark.asyncio
async def test_last_owner_guard_and_permission_revocation_take_effect_immediately(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_administration(session_factory)
    last_owner = await client.delete(
        f"/api/v1/organisation/owners/{ids['owner']}",
        headers=headers(ids),
    )
    assert last_owner.status_code == 409

    grant = await client.post(
        "/api/v1/organisation/permissions",
        headers=headers(ids),
        json={
            "user_id": str(ids["manager"]),
            "permission": "team_membership",
            "scope_type": "team",
            "scope_id": str(ids["team"]),
        },
    )
    assert grant.status_code == 201
    allowed = await client.get(
        f"/api/v1/teams/{ids['team']}/members",
        headers=headers(ids, "manager"),
    )
    assert allowed.status_code == 200
    revoked = await client.delete(
        f"/api/v1/organisation/permissions/{grant.json()['id']}",
        headers=headers(ids),
    )
    assert revoked.status_code == 204
    denied = await client.get(
        f"/api/v1/teams/{ids['team']}/members",
        headers=headers(ids, "manager"),
    )
    assert denied.status_code == 403

    async with session_factory() as session:
        audit = list(
            await session.scalars(
                select(AuditEvent).where(
                    AuditEvent.action.in_(
                        [
                            AuditAction.ORGANISATION_OWNER_REVOKED.value,
                            AuditAction.ORGANISATION_PERMISSION_REVOKED.value,
                        ]
                    )
                )
            )
        )
        assert len(audit) == 1
        assert audit[0].actor_id == ids["owner"]
        assert audit[0].event_metadata["outcome"] == "revoked"
