from copy import deepcopy
from uuid import UUID

import pytest
from app.api.dependencies import enforce_tenant_scope, get_development_identity
from app.main import app
from app.models import FirebaseUidMapping, Organisation, User, UserRole
from app.models.guest import GuestGroupEntry, GuestGroupEntryRevision
from app.models.personal_workspace import PersonalWorkspaceItem
from sqlalchemy import func, select

from tests.test_guest_groups import bearer, install_test_tokens, make_group


def interact_graph() -> dict:
    return {
        "id": "original-session",
        "title": "Original interview",
        "visibility": "private_local",
        "participants": [
            {"id": "alice", "name": "Alice"},
            {"id": "bob", "name": "Bob"},
        ],
        "questions": [
            {
                "id": "root",
                "text": "Shared question",
                "scope": "shared",
                "answers": [
                    {
                        "participant_id": "alice",
                        "body": "Alice's answer",
                        "branches_collapsed": True,
                        "follow_ups": [
                            {
                                "id": "alice-follow-up",
                                "text": "Why Alice?",
                                "scope": "participant",
                                "target_participant_id": "alice",
                                "answers": [
                                    {
                                        "participant_id": "alice",
                                        "body": "Alice's reason",
                                        "branches_collapsed": False,
                                        "follow_ups": [
                                            {
                                                "id": "deep-alice",
                                                "text": "More detail?",
                                                "scope": "participant",
                                                "target_participant_id": "alice",
                                                "answers": [
                                                    {
                                                        "participant_id": "alice",
                                                        "body": "Deep detail",
                                                        "follow_ups": [],
                                                    }
                                                ],
                                            }
                                        ],
                                    }
                                ],
                            }
                        ],
                    },
                    {
                        "participant_id": "bob",
                        "body": "Bob's independent answer",
                        "branches_collapsed": False,
                        "follow_ups": [],
                    },
                ],
            },
            {
                "id": "bob-question",
                "text": "Only Bob",
                "scope": "participant",
                "target_participant_id": "bob",
                "answers": [
                    {"participant_id": "bob", "body": "Bob only", "follow_ups": []}
                ],
            },
        ],
    }


async def add_member(client, group_id: str, uid: str, role: str) -> dict:
    invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("host"),
        json={"role": role},
    )
    assert invitation.status_code == 200, invitation.text
    joined = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer(uid),
        json={"token": invitation.json()["token"], "display_name": uid},
    )
    assert joined.status_code == 200, joined.text
    approved = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{joined.json()['id']}/approve",
        headers=bearer("host"),
    )
    assert approved.status_code == 200, approved.text
    return approved.json()


async def share_interact(client, group_id: str, uid: str = "host") -> dict:
    response = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer(uid),
        json={
            "kind": "interact_session",
            "title": "Shared interview",
            "data": interact_graph(),
            "share_with_group": True,
            "client_import_key": "explicit-copy",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_interact_patch_persists_graph_history_export_and_independent_originals(
    app_client, monkeypatch
) -> None:
    client, sessions = app_client
    install_test_tokens(monkeypatch)
    original = interact_graph()
    imported = await client.post(
        "/api/v1/personal/items/import",
        headers=bearer("host"),
        json={
            "items": [{
                "kind": "interact_session",
                "source_key": "session:original-session",
                "title": original["title"],
                "data": original,
            }]
        },
    )
    assert imported.status_code == 201, imported.text
    private_item = imported.json()["items"][0]
    group = await make_group(client, "host", "Interview team")
    second_group = await make_group(client, "host", "Independent copy")
    entry = await share_interact(client, group["id"])
    second_copy = await share_interact(client, second_group["id"])
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    edited = deepcopy(original)
    edited["title"] = "Shared interview edited"
    edited["questions"][0]["text"] = "Edited shared question"
    answer = edited["questions"][0]["answers"][0]
    answer["body"] = ""
    answer["follow_ups"][0]["text"] = "Edited follow-up"
    answer["follow_ups"][0]["answers"][0]["follow_ups"][0]["text"] = "Edited deep text"
    saved = await client.patch(
        path,
        headers=bearer("host"),
        json={"expected_revision": 1, "title": edited["title"], "data": edited},
    )
    assert saved.status_code == 200, saved.text
    assert saved.json() == {
        **entry, "title": edited["title"], "data": edited, "revision": 2,
    }
    for suffix in ("", "/export"):
        reloaded = await client.get(path + suffix, headers=bearer("host"))
        assert reloaded.status_code == 200, reloaded.text
        assert reloaded.json() == saved.json()

    # A lost successful response must not permit a retry to overwrite new content.
    replay = await client.patch(
        path, headers=bearer("host"),
        json={"expected_revision": 1, "data": original},
    )
    assert replay.status_code == 409
    assert "Reload" in replay.json()["detail"]
    invalid = await client.patch(
        path, headers=bearer("host"), json={"expected_revision": 2},
    )
    assert invalid.status_code == 422
    history = await client.get(path + "/history", headers=bearer("host"))
    assert history.status_code == 200
    assert history.json() == [
        {"revision": 1, "title": entry["title"], "data": original, "edited_by_uid": "host"},
        {"revision": 2, "title": edited["title"], "data": edited, "edited_by_uid": "host"},
    ]
    private_reload = await client.get("/api/v1/personal/items", headers=bearer("host"))
    assert private_reload.json() == [private_item]
    independent = await client.get(
        f"/api/v1/guest/groups/{second_group['id']}/entries/{second_copy['id']}",
        headers=bearer("host"),
    )
    assert independent.json() == second_copy
    assert original == interact_graph()
    async with sessions() as session:
        assert await session.scalar(select(func.count(PersonalWorkspaceItem.id))) == 1
        assert await session.scalar(select(func.count(GuestGroupEntry.id))) == 2
        assert await session.scalar(select(func.count(GuestGroupEntryRevision.id))) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "role,own,status",
    [
        ("admin", True, 200), ("admin", False, 200),
        ("editor", True, 200), ("editor", False, 200),
        ("contributor", True, 200), ("contributor", False, 403),
        ("viewer", True, 403), ("viewer", False, 403),
        ("nonmember", False, 404),
    ],
)
async def test_interact_patch_role_and_authorship_matrix(
    app_client, monkeypatch, role, own, status
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "host", "Role matrix")
    actor = "host" if role == "admin" else "actor"
    if role not in ("admin", "nonmember"):
        # A viewer can own content created before their write role was revoked.
        member = await add_member(
            client, group["id"], actor, "contributor" if role == "viewer" else role
        )
    author = actor if own else "author"
    if author not in ("host", actor):
        await add_member(client, group["id"], author, "contributor")
    entry = await share_interact(client, group["id"], author)
    if role == "viewer":
        changed = await client.patch(
            f"/api/v1/guest/groups/{group['id']}/members/{member['id']}/role",
            headers=bearer("host"), json={"role": "viewer"},
        )
        assert changed.status_code == 200
    edited = interact_graph()
    edited["questions"][0]["answers"][1]["body"] = "Edited Bob"
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    response = await client.patch(
        path, headers=bearer(actor), json={"expected_revision": 1, "data": edited}
    )
    assert response.status_code == status, response.text
    reloaded = await client.get(path, headers=bearer("host"))
    assert reloaded.status_code == 200
    assert reloaded.json() == (
        {**entry, "data": edited, "revision": 2, "updated_by_uid": actor}
        if status == 200 else entry
    )
    history = await client.get(path + "/history", headers=bearer("host"))
    assert [item["revision"] for item in history.json()] == (
        [1, 2] if status == 200 else [1]
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "change,status",
    [
        ("revoked", 403), ("removed", 404), ("archived", 404),
        ("deleted_group", 404), ("deleted_entry", 404),
    ],
)
async def test_interact_open_then_lost_access_cannot_save(
    app_client, monkeypatch, change, status
) -> None:
    client, sessions = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "host", "Long editor")
    member = await add_member(client, group["id"], "actor", "editor")
    entry = await share_interact(client, group["id"])
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    opened = await client.get(path, headers=bearer("actor"))
    assert opened.status_code == 200
    assert opened.json() == entry
    group_path = f"/api/v1/guest/groups/{group['id']}"
    if change == "revoked":
        response = await client.patch(
            f"{group_path}/members/{member['id']}/role",
            headers=bearer("host"), json={"role": "viewer"},
        )
        assert response.status_code == 200
    elif change == "removed":
        response = await client.delete(
            f"{group_path}/members/{member['id']}", headers=bearer("host")
        )
        assert response.status_code == 204
    elif change == "deleted_entry":
        assert (await client.delete(path, headers=bearer("host"))).status_code == 204
    else:
        assert (await client.post(
            group_path + "/archive", headers=bearer("host")
        )).status_code == 200
        if change == "deleted_group":
            assert (await client.delete(
                group_path + "/permanent", headers=bearer("host")
            )).status_code == 204
    draft = deepcopy(entry["data"])
    draft["questions"][0]["text"] = "Late edit must not persist"
    response = await client.patch(
        path, headers=bearer("actor"),
        json={"expected_revision": opened.json()["revision"], "data": draft},
    )
    assert response.status_code == status, response.text
    async with sessions() as session:
        persisted = await session.get(GuestGroupEntry, UUID(entry["id"]))
        if change in ("deleted_group", "deleted_entry"):
            assert persisted is None
        else:
            assert persisted.data == entry["data"]
            assert persisted.revision == 1
        assert await session.scalar(select(func.count(GuestGroupEntryRevision.id))) == 0
    if change != "revoked":
        for suffix in ("", "/history", "/export"):
            assert (await client.get(path + suffix, headers=bearer("actor"))).status_code == 404


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "provider,verified", [("anonymous", False), ("password", False), ("password", True)]
)
async def test_interact_patch_registration_rechecked_on_existing_uid(
    app_client, monkeypatch, provider, verified
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "host", "Registration")
    entry = await share_interact(client, group["id"])
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    edited = interact_graph()
    edited["questions"][0]["text"] = "Verified edit"
    response = await client.patch(
        path, headers=bearer("host", provider, email_verified=verified),
        json={"expected_revision": 1, "data": edited},
    )
    allowed = provider == "password" and verified
    assert response.status_code == (200 if allowed else 403), response.text
    reloaded = await client.get(path, headers=bearer("host"))
    assert reloaded.json()["data"] == (edited if allowed else entry["data"])
    assert reloaded.json()["revision"] == (2 if allowed else 1)


@pytest.mark.asyncio
async def test_interact_patch_organisation_admin_has_no_group_authority(
    app_client, monkeypatch
) -> None:
    client, sessions = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "host", "Organisation-independent")
    await add_member(client, group["id"], "org-admin-viewer", "viewer")
    entry = await share_interact(client, group["id"])
    async with sessions() as session:
        organisation = Organisation(name="Organisation", slug="interact-edit-org")
        session.add(organisation)
        await session.flush()
        for uid in ("org-admin-viewer", "org-admin-outsider"):
            user = User(
                organisation_id=organisation.id, email=f"{uid}@example.invalid",
                display_name=uid, role=UserRole.ADMIN,
            )
            session.add(user)
            await session.flush()
            session.add(FirebaseUidMapping(firebase_uid=uid, user_id=user.id))
        await session.commit()
    app.dependency_overrides.pop(get_development_identity, None)
    app.dependency_overrides.pop(enforce_tenant_scope, None)
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    for uid, status in (("org-admin-viewer", 403), ("org-admin-outsider", 404)):
        identity = await client.get("/api/v1/auth/me", headers=bearer(uid))
        assert identity.status_code == 200, identity.text
        assert identity.json()["role"] == "admin"
        denied = await client.patch(
            path, headers=bearer(uid),
            json={"expected_revision": 1, "data": {"questions": []}},
        )
        assert denied.status_code == status, denied.text
    # Group admin remains eligible without any organisation account.
    allowed = await client.patch(
        path, headers=bearer("host"),
        json={"expected_revision": 1, "data": interact_graph()},
    )
    assert allowed.status_code == 200, allowed.text
    assert allowed.json()["revision"] == 2
    assert allowed.json()["created_by_uid"] == "host"
