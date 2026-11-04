from datetime import datetime, timedelta, timezone
from uuid import UUID

import pytest
from sqlalchemy import select

from app.models.guest import GuestGroup, GuestGroupMembership
from app.services.interact_search import session_matches
from tests.test_answer_governance import headers, seed_governance
from tests.test_guided import add_participant, add_question, answer, create_session
from tests.test_guest_groups import make_group
from tests.test_personal_workspace import bearer, install_test_tokens


def graph():
    return {
        "id": "same-session-id", "title": "Interview",
        "participants": [{"id": "alice", "name": "Alice"}, {"id": "bob", "name": "Bob"}],
        "questions": [{
            "id": "root", "text": "Main prompt", "scope": "shared",
            "answers": [{
                "participant_id": "alice", "body": "Ordinary answer", "branches_collapsed": True,
                "follow_ups": [{
                    "id": "branch", "text": "sentinel follow-up", "scope": "participant",
                    "target_participant_id": "alice",
                    "answers": [{
                        "participant_id": "alice", "body": "sentinel nested answer",
                        "follow_ups": [{
                            "id": "deep", "text": "sentinel recursive detail", "answers": [],
                        }],
                    }],
                }],
            }, {"participant_id": "bob", "body": "Unrelated answer", "follow_ups": []}],
        }],
    }


def test_recursive_matching_keeps_ownership_and_excludes_deleted_subtrees():
    original = graph()
    hits = session_matches("sentinel", original, metadata={})
    assert {hit["question_id"] for hit in hits} == {"branch", "deep"}
    assert all(hit["participant_id"] == "alice" for hit in hits)
    assert original["questions"][0]["answers"][0]["branches_collapsed"] is True
    original["questions"][0]["deleted_at"] = "2026-10-08"
    assert session_matches("sentinel", original, metadata={}) == []
    unicode_hits = session_matches("STRASSE", {"title": "Straße", "questions": []}, metadata={})
    assert unicode_hits[0]["question_id"] is None
    assert unicode_hits[0]["snippet"] == "Straße"


@pytest.mark.asyncio
async def test_private_and_group_search_enforces_current_membership_and_uid(app_client, monkeypatch):
    client, factory = app_client
    install_test_tokens(monkeypatch)
    payload = {
        "kind": "interact_session", "source_key": "session:same-session-id",
        "title": "Interview", "data": graph(),
    }
    created = await client.post("/api/v1/personal/items/import",
        headers=bearer("owner"), json={"items": [payload]})
    assert created.status_code == 201, created.text
    group = await make_group(client, "owner", "Search team")
    shared = await client.post(f"/api/v1/guest/groups/{group['id']}/entries",
        headers=bearer("owner"), json={
            "kind": "interact_session", "title": "Interview", "data": graph(),
            "share_with_group": True,
        })
    assert shared.status_code == 201, shared.text

    async def search(uid="owner"):
        result = await client.get("/api/v1/personal/interact/search",
            headers=bearer(uid), params={"query": "sentinel"})
        assert result.status_code == 200, result.text
        return result.json()

    owner_hits = (await search())["results"]
    assert {hit["source"] for hit in owner_hits} == {"Private", "Group: Search team"}
    assert {hit["question_id"] for hit in owner_hits} == {"branch", "deep"}
    assert (await search("other"))["results"] == []
    async with factory() as session:
        member = GuestGroupMembership(
            group_id=UUID(group["id"]), firebase_uid="other", display_name="Other",
            role="viewer", status="pending",
        )
        session.add(member)
        await session.commit()
    assert (await search("other"))["results"] == []
    async with factory() as session:
        member = await session.scalar(select(GuestGroupMembership).where(
            GuestGroupMembership.firebase_uid == "other"))
        member.status = "active"
        await session.commit()
    assert {hit["source"] for hit in (await search("other"))["results"]} == {"Group: Search team"}
    async with factory() as session:
        member = await session.scalar(select(GuestGroupMembership).where(
            GuestGroupMembership.firebase_uid == "other"))
        member.status = "removed"
        await session.commit()
    assert (await search("other"))["results"] == []
    async with factory() as session:
        saved_group = await session.get(GuestGroup, UUID(group["id"]))
        saved_group.archived_at = datetime.now(timezone.utc)
        await session.commit()
    assert {hit["source"] for hit in (await search())["results"]} == {"Private"}
    async with factory() as session:
        saved_group = await session.get(GuestGroup, UUID(group["id"]))
        saved_group.archived_at = None
        saved_group.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        await session.commit()
    assert {hit["source"] for hit in (await search())["results"]} == {"Private"}
    for denied in [bearer("owner", "anonymous"), bearer("owner", verified=False)]:
        result = await client.get("/api/v1/personal/interact/search",
            headers=denied, params={"query": "sentinel"})
        assert result.status_code == 403


@pytest.mark.asyncio
async def test_organisation_search_matches_editor_visibility_and_deleted_graph(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    private = await create_session(client, ids, title="Private sentinel review")
    participant = await add_participant(client, ids, private["id"], "Alice")
    root = await add_question(client, ids, private["id"], "Main prompt")
    saved_answer = await answer(client, ids, root["id"], participant["id"], "sentinel answer")
    child = await client.post(
        f"/api/v1/guided/answers/{saved_answer['id']}/follow-ups",
        headers=headers(ids, "employee"), json={"text": "sentinel branch"})
    assert child.status_code == 201
    child_answer = await answer(client, ids, child.json()["id"], participant["id"], "sentinel deep answer")
    nested = await client.post(
        f"/api/v1/guided/answers/{child_answer['id']}/follow-ups",
        headers=headers(ids, "employee"), json={"text": "sentinel nested"})
    assert nested.status_code == 201

    async def search(user="employee", organisation="organisation", limit=25):
        result = await client.get("/api/v1/guided/sessions/search",
            headers=headers(ids, user, organisation),
            params={"query": "sentinel", "limit": limit})
        assert result.status_code == 200, result.text
        return result.json()

    hits = (await search())["results"]
    assert {hit["question_id"] for hit in hits} == {
        None, root["id"], child.json()["id"], nested.json()["id"],
    }
    assert all(hit["participant_id"] == participant["id"] for hit in hits if hit["question_id"])
    assert (await search("admin"))["results"] == []  # private sessions stay creator-only
    assert (await search("finance_owner"))["results"] == []
    assert (await search("outsider", "other_organisation"))["results"] == []
    limited = await search(limit=1)
    assert limited["partial"] is True and len(limited["results"]) == 1
    changed = await client.patch(f"/api/v1/guided/sessions/{private['id']}",
        headers=headers(ids, "employee"), json={"visibility": "department"})
    assert changed.status_code == 200
    assert (await search("finance_owner"))["results"]
    assert (await search("people_owner"))["results"] == []
    assert all(hit["department"]["name"] == "Finance" for hit in (await search())["results"])
    deleted = await client.delete(f"/api/v1/guided/questions/{child.json()['id']}",
        headers=headers(ids, "employee"))
    assert deleted.status_code == 200
    remaining = (await search())["results"]
    assert child.json()["id"] not in {hit["question_id"] for hit in remaining}
    assert nested.json()["id"] not in {hit["question_id"] for hit in remaining}
    changed = await client.patch(f"/api/v1/guided/sessions/{private['id']}",
        headers=headers(ids, "employee"), json={"visibility": "organisation"})
    assert changed.status_code == 200
    assert (await search("people_owner"))["results"]
    assert (await search("admin"))["results"]
