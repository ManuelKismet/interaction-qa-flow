from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4
import pytest
from sqlalchemy import select
from app.models import FirebaseUidMapping, Team, TeamMembership, User
from app.models.guest import GuestGroupMembership
from app.models.suggestion_bank import BankActivity, BankSuggestion
from app.main import app
from app.api.dependencies import get_guest_identity, GuestIdentity
from tests.test_suggestion_bank import bank, auth, create, action


@pytest.mark.asyncio
async def test_action_replay_content_conflict_support_once_and_permission_revocation(
    bank,
):
    c, factory, ids = bank
    item = (
        await c.post("/api/v1/suggestion-bank", headers=auth(), json=create(ids))
    ).json()
    data = {
        "action": "respond",
        "expected_revision": 1,
        "client_key": "response-1",
        "text": "We will review this Friday",
    }
    first = await c.post(
        "/api/v1/suggestion-bank/" + item["id"] + "/actions",
        headers=auth("admin"),
        json=data,
    )
    retry = await c.post(
        "/api/v1/suggestion-bank/" + item["id"] + "/actions",
        headers=auth("admin"),
        json=data,
    )
    assert first.status_code == retry.status_code == 200
    assert first.json()["revision"] == retry.json()["revision"]
    changed = await c.post(
        "/api/v1/suggestion-bank/" + item["id"] + "/actions",
        headers=auth("admin"),
        json={**data, "text": "Different decision"},
    )
    assert changed.status_code == 409
    supported = await action(c, first.json(), "support", who="employee")
    again = await action(c, supported.json(), "support", who="employee")
    assert again.json()["revision"] == supported.json()["revision"]
    async with factory() as session:
        admin = await session.get(User, ids["admin"])
        admin.status = "inactive"
        await session.commit()
    denied = await action(c, again.json(), "respond")
    assert denied.status_code == 403


@pytest.mark.asyncio
async def test_team_membership_filters_every_read_and_nia(bank):
    c, factory, ids = bank
    async with factory() as session:
        team = Team(organisation_id=ids["organisation"], name="Facilities")
        session.add(team)
        await session.flush()
        session.add(
            TeamMembership(
                organisation_id=ids["organisation"],
                team_id=team.id,
                user_id=ids["employee"],
            )
        )
        await session.commit()
        team_id = team.id
    payload = create(ids, scope_type="team", scope_id=str(team_id))
    item = (
        await c.post("/api/v1/suggestion-bank", headers=auth(), json=payload)
    ).json()
    assert item["scope_type"] == "team"
    denied = await c.get("/api/v1/suggestion-bank/" + item["id"], headers=auth("admin"))
    assert denied.status_code == 404
    async with factory() as session:
        member = await session.scalar(
            select(TeamMembership).where(
                TeamMembership.user_id == ids["employee"],
                TeamMembership.team_id == team_id,
            )
        )
        await session.delete(member)
        await session.commit()
    assert (
        await c.get("/api/v1/suggestion-bank/" + item["id"], headers=auth())
    ).status_code == 404
    nia = await c.get(
        "/api/v1/suggestion-bank/nia",
        headers=auth(),
        params={"scope_type": "team", "scope_id": str(team_id), "query": "printer"},
    )
    assert nia.status_code == 404


@pytest.mark.asyncio
async def test_group_official_workflow_handoff_and_archive(bank):
    c, factory, _ = bank
    group = (
        await c.post(
            "/api/v1/guest/groups",
            headers=auth("admin"),
            json={"name": "Facilities", "display_name": "Facilities owner"},
        )
    ).json()
    payload = {
        "scope_type": "group",
        "scope_id": group["id"],
        "client_key": "one",
        "title": "Refill printer",
        "problem": "Empty tray",
        "proposal": "Refill it",
        "benefit": "Less delay",
    }
    item = (
        await c.post(
            "/api/v1/suggestion-bank?realm=group", headers=auth("admin"), json=payload
        )
    ).json()

    async def group_action(item, kind, **extra):
        return await c.post(
            "/api/v1/suggestion-bank/" + item["id"] + "/actions?realm=group",
            headers=auth("admin"),
            json={
                "action": kind,
                "client_key": str(uuid4()),
                "expected_revision": item["revision"],
                "text": "Agreed facilities workflow",
                **extra,
            },
        )

    item = (await group_action(item, "status", status="under_review")).json()
    async with factory() as session:
        member = await session.scalar(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == UUID(group["id"]),
                GuestGroupMembership.firebase_uid == "admin",
            )
        )
        member_id = member.id
    item = (
        await group_action(
            item,
            "assign",
            target_id=str(member_id),
            review_due_at=(datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        )
    ).json()
    item = (await group_action(item, "status", status="planned")).json()
    review = await group_action(item, "start_interact")
    assert review.status_code == 200, review.text
    entry = await c.get(
        "/api/v1/guest/groups/"
        + group["id"]
        + "/entries/"
        + review.json()["interact_id"],
        headers=auth("admin"),
    )
    assert entry.status_code == 200, entry.text
    assert entry.json()["data"]["source_suggestion_id"] == item["id"]
    assert len(entry.json()["data"]["questions"]) == 4
    await c.post(
        "/api/v1/guest/groups/" + group["id"] + "/archive", headers=auth("admin")
    )
    assert (
        await c.get(
            "/api/v1/suggestion-bank/" + item["id"] + "?realm=group",
            headers=auth("admin"),
        )
    ).status_code == 404


@pytest.mark.asyncio
async def test_anonymous_and_unverified_groups_denied(bank):
    c, _, _ = bank

    async def anonymous():
        return GuestIdentity(
            firebase_uid="admin", sign_in_provider="anonymous", email_verified=True
        )

    app.dependency_overrides[get_guest_identity] = anonymous
    assert (
        await c.get("/api/v1/suggestion-bank/scopes?realm=group", headers=auth("admin"))
    ).status_code == 403

    async def unverified():
        return GuestIdentity(
            firebase_uid="admin", sign_in_provider="password", email_verified=False
        )

    app.dependency_overrides[get_guest_identity] = unverified
    assert (
        await c.get("/api/v1/suggestion-bank/scopes?realm=group", headers=auth("admin"))
    ).status_code == 403


@pytest.mark.asyncio
async def test_group_bank_acquires_rate_budget_before_group_lock(bank, monkeypatch):
    c, _, _ = bank
    from app.services.guest import GuestService

    group = (
        await c.post(
            "/api/v1/guest/groups",
            headers=auth("admin"),
            json={"name": "Lock order", "display_name": "Owner"},
        )
    ).json()
    order = []
    original_budget = GuestService._rate_limit
    original_group = GuestService._group

    async def budget(self, *args, **kwargs):
        order.append("budget")
        return await original_budget(self, *args, **kwargs)

    async def locked_group(self, *args, **kwargs):
        order.append("group")
        return await original_group(self, *args, **kwargs)

    monkeypatch.setattr(GuestService, "_rate_limit", budget)
    monkeypatch.setattr(GuestService, "_group", locked_group)
    payload = {
        "scope_type": "group",
        "scope_id": group["id"],
        "client_key": "lock-order",
        "title": "Printer",
        "problem": "Empty tray",
        "proposal": "Refill it",
        "benefit": "Less waiting",
    }
    result = await c.post(
        "/api/v1/suggestion-bank?realm=group", headers=auth("admin"), json=payload
    )
    assert result.status_code == 201, result.text
    assert order.index("budget") < order.index("group")
