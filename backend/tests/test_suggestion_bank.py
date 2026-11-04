from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4
import pytest
import pytest_asyncio
from fastapi import Request
from app.api.dependencies import GuestIdentity, get_guest_identity
from app.main import app
from app.models import FirebaseUidMapping
from tests.test_answer_governance import seed_governance


@pytest_asyncio.fixture
async def bank(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    async with factory() as session:
        for key in ("admin", "employee", "finance_owner", "people_owner", "outsider"):
            session.add(FirebaseUidMapping(firebase_uid=key, user_id=ids[key]))
        await session.commit()

    async def identity(request: Request):
        return GuestIdentity(
            firebase_uid=request.headers.get(
                "Authorization", "Bearer employee"
            ).split()[-1],
            sign_in_provider="password",
            email_verified=True,
        )

    app.dependency_overrides[get_guest_identity] = identity
    return client, factory, ids


def auth(who="employee"):
    return {"Authorization": "Bearer " + who}


def create(ids, **extra):
    return {
        "scope_type": "organisation",
        "scope_id": str(ids["organisation"]),
        "kind": "etiquette",
        "title": "Refill the printer tray",
        "problem": "The last sheet is used without refilling",
        "proposal": "Refill the tray after printing its last sheet",
        "benefit": "The next colleague can print",
        "client_key": str(uuid4()),
        **extra,
    }


async def action(client, item, kind, who="admin", **extra):
    return await client.post(
        f"/api/v1/suggestion-bank/{item['id']}/actions",
        headers=auth(who),
        json={
            "action": kind,
            "expected_revision": item["revision"],
            "client_key": str(uuid4()),
            "text": "Reviewed with the team",
            **extra,
        },
    )


@pytest.mark.asyncio
async def test_submission_retry_visibility_and_official_authority(bank):
    c, _, ids = bank
    data = create(ids)
    first = await c.post("/api/v1/suggestion-bank", headers=auth(), json=data)
    assert first.status_code == 201, first.text
    item = first.json()
    assert (
        item["status"] == "submitted" and item["unanswered"] and not item["can_manage"]
    )
    retry = await c.post("/api/v1/suggestion-bank", headers=auth(), json=data)
    assert retry.json()["id"] == item["id"]
    changed = await c.post(
        "/api/v1/suggestion-bank",
        headers=auth(),
        json={**data, "proposal": "Different"},
    )
    assert changed.status_code == 409
    forbidden = await action(c, item, "status", who="employee", status="under_review")
    assert forbidden.status_code == 403
    outsider = await c.get(
        "/api/v1/suggestion-bank/" + item["id"], headers=auth("outsider")
    )
    assert outsider.status_code == 404
    assert (await c.get("/api/v1/suggestion-bank", headers=auth("outsider"))).json()[
        "items"
    ] == []
    override = await c.get(
        "/api/v1/suggestion-bank", headers={**auth(), "X-User-ID": str(ids["admin"])}
    )
    assert override.status_code == 400
    resp = await action(
        c, item, "respond", text="Thank you. Facilities will review this on Friday."
    )
    assert resp.status_code == 200, resp.text
    assert not resp.json()["unanswered"]
    updates = (
        await c.get("/api/v1/suggestion-bank?queue=updates", headers=auth())
    ).json()["items"]
    assert len(updates) == 1 and updates[0]["unread"]
    await c.post(
        "/api/v1/suggestion-bank/" + item["id"] + "/seen",
        params={"revision": resp.json()["revision"]},
        headers=auth(),
    )
    assert (
        await c.get("/api/v1/suggestion-bank?queue=updates", headers=auth())
    ).json()["items"] == []


@pytest.mark.asyncio
async def test_owner_workflow_practice_closure_history_and_stale_write(bank):
    c, _, ids = bank
    item = (
        await c.post("/api/v1/suggestion-bank", headers=auth(), json=create(ids))
    ).json()
    original = item
    item = (await action(c, item, "status", status="under_review")).json()
    no_owner = await action(c, item, "status", status="planned")
    assert no_owner.status_code == 409
    item = (
        await action(
            c,
            item,
            "assign",
            target_id=str(ids["admin"]),
            review_due_at=(datetime.now(timezone.utc) + timedelta(days=3)).isoformat(),
        )
    ).json()
    assert item["owner_name"] == "Admin"
    item = (await action(c, item, "status", status="planned")).json()
    item = (
        await action(
            c,
            item,
            "adopt_practice",
            text="Please refill the printer tray when you use its last sheet.",
        )
    ).json()
    item = (await action(c, item, "status", status="in_progress")).json()
    item = (await action(c, item, "status", status="implemented")).json()
    practices = (
        await c.get("/api/v1/suggestion-bank?queue=practices", headers=auth())
    ).json()["items"]
    assert practices[0]["practice"] == item["practice"]
    revised = await action(
        c,
        item,
        "revise_practice",
        text="Refill the tray with the correct paper size after the last sheet.",
    )
    assert revised.status_code == 200, revised.text
    assert any(e["action"] == "adopt_practice" for e in revised.json()["activities"])
    stale = await action(c, original, "respond")
    assert stale.status_code == 409
    foreign_owner = await action(
        c,
        revised.json(),
        "assign",
        target_id=str(ids["outsider"]),
        review_due_at=(datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
    )
    assert foreign_owner.status_code == 403


@pytest.mark.asyncio
async def test_duplicates_preserve_examples_and_dont_leak_other_departments(bank):
    c, _, ids = bank
    first = (
        await c.post("/api/v1/suggestion-bank", headers=auth(), json=create(ids))
    ).json()
    second = (
        await c.post(
            "/api/v1/suggestion-bank",
            headers=auth(),
            json=create(
                ids, title="Printer paper refill", problem="Repeated printer delays"
            ),
        )
    ).json()
    second = (
        await action(
            c,
            second,
            "comment",
            who="employee",
            text="This happened in our office yesterday.",
        )
    ).json()
    linked = await action(c, second, "link_duplicate", target_id=first["id"])
    assert linked.status_code == 200, linked.text
    assert linked.json()["problem"] == "Repeated printer delays"
    assert any(
        e["text"] == "This happened in our office yesterday."
        for e in linked.json()["activities"]
    )
    cycle = await action(c, first, "link_duplicate", target_id=second["id"])
    assert cycle.status_code == 409
    private = (
        await c.post(
            "/api/v1/suggestion-bank",
            headers=auth("people_owner"),
            json=create(
                ids,
                scope_type="department",
                scope_id=str(ids["people_department"]),
                title="Printer secret people proposal",
            ),
        )
    ).json()
    listing = (await c.get("/api/v1/suggestion-bank", headers=auth())).json()["items"]
    assert private["id"] not in [x["id"] for x in listing]
    helpers = await c.get(
        "/api/v1/suggestion-bank/nia",
        headers=auth(),
        params={
            "scope_type": "organisation",
            "scope_id": str(ids["organisation"]),
            "query": "Printer",
        },
    )
    assert helpers.status_code == 200
    assert helpers.json()["prompts"] == []  # Current-state guidance belongs to ANI.
    assert private["id"] not in [x["id"] for x in helpers.json()["related"]]
    assert first["id"] in [x["id"] for x in helpers.json()["related"]]
    denied = await c.get(
        "/api/v1/suggestion-bank/" + private["id"], headers=auth("admin")
    )
    assert denied.status_code == 404  # Review authority does not grant visibility.


@pytest.mark.asyncio
async def test_escalation_requires_explicit_audience_keeps_original_and_no_history_leak(
    bank,
):
    c, _, ids = bank
    item = (
        await c.post(
            "/api/v1/suggestion-bank",
            headers=auth("finance_owner"),
            json=create(
                ids, scope_type="department", scope_id=str(ids["finance_department"])
            ),
        )
    ).json()
    item = (
        await action(
            c, item, "comment", who="finance_owner", text="A department-only example"
        )
    ).json()
    target = {"scope_type": "organisation", "scope_id": str(ids["organisation"])}
    denied = await action(c, item, "escalate", who="finance_owner", target_scope=target)
    assert denied.status_code == 409
    escalated = await action(
        c,
        item,
        "escalate",
        who="finance_owner",
        target_scope=target,
        confirm_visibility=True,
        text="Please review organisation-wide",
    )
    assert escalated.status_code == 200, escalated.text
    assert escalated.json()["scope_type"] == "department"
    org = (await c.get("/api/v1/suggestion-bank", headers=auth("people_owner"))).json()[
        "items"
    ]
    assert len(org) == 1 and org[0]["scope_type"] == "organisation"
    detail = (
        await c.get(
            "/api/v1/suggestion-bank/" + org[0]["id"], headers=auth("people_owner")
        )
    ).json()
    assert "A department-only example" not in str(detail)


@pytest.mark.asyncio
async def test_interact_handoff_and_verified_knowledge_link(bank):
    c, _, ids = bank
    item = (
        await c.post("/api/v1/suggestion-bank", headers=auth(), json=create(ids))
    ).json()
    item = (await action(c, item, "status", status="under_review")).json()
    item = (
        await action(
            c,
            item,
            "assign",
            target_id=str(ids["admin"]),
            review_due_at=(datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        )
    ).json()
    item = (await action(c, item, "status", status="planned")).json()
    review = await action(c, item, "start_interact")
    assert review.status_code == 200, review.text
    assert review.json()["interact_id"]
    no_verified = await action(
        c, review.json(), "link_knowledge", target_id=str(ids["finance_question"])
    )
    assert no_verified.status_code == 409


@pytest.mark.asyncio
async def test_group_viewer_boundary_revocation_and_other_group_isolation(bank):
    c, factory, _ = bank
    group = (
        await c.post(
            "/api/v1/guest/groups",
            headers=auth("admin"),
            json={"name": "Facilities", "display_name": "Facilities owner"},
        )
    ).json()
    from app.models.guest import GuestGroupMembership

    async with factory() as session:
        viewer = GuestGroupMembership(
            group_id=UUID(group["id"]),
            firebase_uid="employee",
            display_name="Employee",
            role="viewer",
            status="active",
        )
        session.add(viewer)
        await session.commit()
        viewer_id = viewer.id
    payload = {
        "scope_type": "group",
        "scope_id": group["id"],
        "client_key": "group-printer",
        "title": "Printer etiquette",
        "problem": "Empty tray",
        "proposal": "Refill it",
        "benefit": "Less delay",
    }
    denied = await c.post(
        "/api/v1/suggestion-bank?realm=group", headers=auth(), json=payload
    )
    assert denied.status_code == 403
    posted = await c.post(
        "/api/v1/suggestion-bank?realm=group", headers=auth("admin"), json=payload
    )
    assert posted.status_code == 201, posted.text
    item = posted.json()
    assert (
        await c.get(
            "/api/v1/suggestion-bank/" + item["id"] + "?realm=group", headers=auth()
        )
    ).status_code == 200
    async with factory() as session:
        viewer = await session.get(GuestGroupMembership, viewer_id)
        viewer.status = "removed"
        await session.commit()
    assert (
        await c.get(
            "/api/v1/suggestion-bank/" + item["id"] + "?realm=group", headers=auth()
        )
    ).status_code == 404
    assert (
        await c.get("/api/v1/suggestion-bank/" + item["id"], headers=auth("admin"))
    ).status_code == 404
