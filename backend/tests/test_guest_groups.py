from datetime import datetime, timedelta, timezone
from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.api import dependencies
from app.api.dependencies import enforce_tenant_scope, get_development_identity
from app.main import app
from app.models.guest import (
    GuestGroup,
    GuestGroupEntry,
    GuestGroupInvitation,
    GuestGroupMembership,
)
from app.models import FirebaseUidMapping, Organisation, User, UserRole
from app.services import guest as guest_service

PROJECT_ID = "intqaflow-dev"


def bearer(uid: str, provider: str = "anonymous") -> dict[str, str]:
    token = "-".join(("test", provider, uid))
    return {"Authorization": "".join(("Bear", "er ", token))}


def install_test_tokens(monkeypatch) -> None:
    def verify(token: str, _settings) -> dict[str, object]:
        _, provider, uid = token.split("-", 2)
        return {
            "aud": PROJECT_ID,
            "iss": f"https://securetoken.google.com/{PROJECT_ID}",
            "sub": uid,
            "firebase": {"sign_in_provider": provider},
        }

    monkeypatch.setattr(dependencies, "verify_id_token", verify)


async def make_group(client, uid: str, name: str) -> dict:
    response = await client.post(
        "/api/v1/guest/groups",
        headers=bearer(uid),
        json={"name": name, "display_name": f"{uid} display"},
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_group_invites_roles_removal_and_group_boundary(app_client, monkeypatch) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    owner = await make_group(client, "guest-owner", "Field research")
    group_id = owner["id"]
    async with session_factory() as db:
        group_row = await db.scalar(
            select(GuestGroup).where(GuestGroup.id == UUID(group_id))
        )
        group_row.expires_at = datetime.now(timezone.utc) + timedelta(days=1)
        await db.commit()
    listed_groups = await client.get(
        "/api/v1/guest/groups", headers=bearer("guest-owner")
    )
    assert listed_groups.status_code == 200
    assert datetime.fromisoformat(listed_groups.json()[0]["expires_at"]) > (
        datetime.now(timezone.utc) + timedelta(days=89)
    )

    invite_response = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("guest-owner"),
        json={"role": "contributor", "expires_in_hours": 12},
    )
    assert invite_response.status_code == 200, invite_response.text
    invitation = invite_response.json()
    token = invitation["token"]
    active_invitations = await client.get(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("guest-owner"),
    )
    assert active_invitations.status_code == 200
    assert active_invitations.json() == [
        {
            "id": invitation["id"],
            "role": "contributor",
            "expires_at": invitation["expires_at"],
        }
    ]
    assert "token" not in active_invitations.json()[0]
    hidden_invitations = await client.get(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("guest-outsider"),
    )
    assert hidden_invitations.status_code == 404

    preview = await client.post(
        "/api/v1/guest/invitations/preview",
        headers=bearer("guest-joiner"),
        json={"token": token},
    )
    assert preview.status_code == 200
    assert preview.json() == {"valid": True}
    assert "name" not in preview.json()
    pending = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("guest-joiner"),
        json={"token": token, "display_name": "Researcher"},
    )
    assert pending.status_code == 200
    assert pending.json()["status"] == "pending"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}", headers=bearer("guest-joiner")
        )
    ).status_code == 404
    replay = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("guest-other"),
        json={"token": token, "display_name": "Other"},
    )
    assert replay.status_code == 409

    approve = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{pending.json()['id']}/approve",
        headers=bearer("guest-owner"),
    )
    assert approve.status_code == 200
    assert approve.json()["status"] == "active"
    knowledge = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("guest-joiner"),
        json={
            "kind": "knowledge",
            "title": "Password rotation policy",
            "data": {"body": "Rotate credentials every quarter."},
        },
    )
    assert knowledge.status_code == 201, knowledge.text
    without_share_confirmation = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("guest-joiner"),
        json={
            "kind": "interact_session",
            "title": "Must remain private",
            "data": {"questions": []},
        },
    )
    assert without_share_confirmation.status_code == 422
    session = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("guest-joiner"),
        json={
            "kind": "interact_session",
            "title": "Interview",
            "share_with_group": True,
            "data": {
                "participants": [{"id": "p1", "name": "Synthetic participant"}],
                "questions": [
                    {
                        "id": "q1",
                        "text": "Primary question",
                        "answers": [
                            {"participant_id": "p1", "follow_up": {"id": "q2"}}
                        ],
                    }
                ],
            },
        },
    )
    assert session.status_code == 201, session.text

    search = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("guest-owner"),
        params={"query": "passw", "kind": "knowledge"},
    )
    assert [item["id"] for item in search.json()] == [knowledge.json()["id"]]
    assert search.json()[0]["data"]["body"] == "Rotate credentials every quarter."

    editor_invite = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("guest-owner"),
        json={"role": "contributor"},
    )
    editor_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("guest-editor"),
        json={"token": editor_invite.json()["token"], "display_name": "Editor"},
    )
    await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{editor_join.json()['id']}/approve",
        headers=bearer("guest-owner"),
    )
    changed = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-editor"),
        json={"title": "Updated password policy"},
    )
    assert changed.status_code == 403
    admin_edit = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-owner"),
        json={"title": "Admin-reviewed password policy"},
    )
    assert admin_edit.status_code == 200
    changed_by_author = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-joiner"),
        json={"title": "Updated password policy"},
    )
    assert changed_by_author.status_code == 200
    history = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/history",
        headers=bearer("guest-owner"),
    )
    assert [item["revision"] for item in history.json()] == [1, 2, 3]
    exported = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/export",
        headers=bearer("guest-owner"),
    )
    assert exported.status_code == 200

    other_group = await make_group(client, "guest-other", "Other group")
    for path in (
        f"/api/v1/guest/groups/{group_id}",
        f"/api/v1/guest/groups/{group_id}/entries?query=password",
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/history",
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/export",
    ):
        response = await client.get(path, headers=bearer("guest-other"))
        assert response.status_code == 404, (path, response.text)
    assert other_group["id"] != group_id

    removed = await client.delete(
        f"/api/v1/guest/groups/{group_id}/members/{pending.json()['id']}",
        headers=bearer("guest-owner"),
    )
    assert removed.status_code == 204
    for path in (
        f"/api/v1/guest/groups/{group_id}",
        f"/api/v1/guest/groups/{group_id}/entries?query=password",
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/export",
    ):
        response = await client.get(path, headers=bearer("guest-joiner"))
        assert response.status_code == 404, (path, response.text)

    async with session_factory() as db:
        assert await db.scalar(select(func.count(User.id))) == 0
        assert await db.scalar(select(GuestGroup.created_by_uid).where(
            GuestGroup.id == UUID(group_id)
        )) == "guest-owner"


@pytest.mark.asyncio
async def test_guest_role_viewer_admin_transfer_and_no_org_escalation(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "transfer-host", "Transfer test")
    group_id = group["id"]
    invite = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-host"),
        json={"role": "viewer"},
    )
    listed_invites = await client.get(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-host"),
    )
    assert listed_invites.status_code == 200
    assert listed_invites.json()[0]["id"] == invite.json()["id"]
    assert "token" not in listed_invites.json()[0]
    joined = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("transfer-viewer"),
        json={"token": invite.json()["token"], "display_name": "Viewer"},
    )
    approve = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{joined.json()['id']}/approve",
        headers=bearer("transfer-host"),
    )
    assert approve.status_code == 200
    denied = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("transfer-viewer"),
        json={"kind": "knowledge", "title": "No write", "data": {}},
    )
    assert denied.status_code == 403
    revocable = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-host"),
        json={"role": "contributor"},
    )
    revoked = await client.delete(
        f"/api/v1/guest/groups/{group_id}/invitations/{revocable.json()['id']}",
        headers=bearer("transfer-host"),
    )
    assert revoked.status_code == 204
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}/invitations",
            headers=bearer("transfer-host"),
        )
    ).json() == []

    transfer = await client.post(
        f"/api/v1/guest/groups/{group_id}/transfer-administration",
        headers=bearer("transfer-host"),
        params={"member_id": joined.json()["id"]},
    )
    assert transfer.status_code == 200, transfer.text
    assert transfer.json()["role"] == "admin"
    old_admin = await client.get(
        f"/api/v1/guest/groups/{group_id}", headers=bearer("transfer-host")
    )
    assert old_admin.status_code == 200
    assert old_admin.json()["role"] == "contributor"
    no_more_admin = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-host"),
        json={},
    )
    assert no_more_admin.status_code == 403

    linked_identity = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("transfer-viewer", "password"),
    )
    assert linked_identity.status_code == 200
    unlinked_registered = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("registered-org-user", "password"),
    )
    assert unlinked_registered.status_code == 404
    async with session_factory() as db:
        organisation_id = UUID("00000000-0000-0000-0000-000000000001")
        registered_user_id = UUID("00000000-0000-0000-0000-000000000002")
        db.add(
            Organisation(
                id=organisation_id,
                name="Registered organisation",
                slug="registered-organisation",
            )
        )
        db.add(
            User(
                id=registered_user_id,
                organisation_id=organisation_id,
                email="registered@example.invalid",
                display_name="Registered user",
                role=UserRole.EMPLOYEE,
            )
        )
        db.add(
            FirebaseUidMapping(
                firebase_uid="registered-org-user",
                user_id=registered_user_id,
            )
        )
        await db.commit()
    app.dependency_overrides.pop(get_development_identity, None)
    app.dependency_overrides.pop(enforce_tenant_scope, None)
    org_route = await client.get(
        "/api/v1/auth/me",
        headers=bearer("registered-org-user", "password"),
    )
    assert org_route.status_code == 200
    assert org_route.json()["organisation_id"] == str(organisation_id)
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=bearer("registered-org-user", "password"),
        )
    ).status_code == 404
    anonymous_org_route = await client.get(
        "/api/v1/auth/me", headers=bearer("new-anonymous-user")
    )
    assert anonymous_org_route.status_code == 401
    wrong_header = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers={**bearer("transfer-viewer"), "X-User-ID": "admin"},
    )
    assert wrong_header.status_code == 400
    forged_org = await client.post(
        "/api/v1/guest/groups",
        headers=bearer("transfer-host"),
        json={
            "name": "Forged tenant",
            "display_name": "Host",
            "organisation_id": "00000000-0000-0000-0000-000000000001",
        },
    )
    assert forged_org.status_code == 422

    registered_create = await client.post(
        "/api/v1/guest/groups",
        headers=bearer("registered-org-user", "password"),
        json={"name": "Not anonymous", "display_name": "Org user"},
    )
    assert registered_create.status_code == 403

    async with session_factory() as db:
        memberships = list(
            await db.scalars(
                select(GuestGroupMembership).where(
                    GuestGroupMembership.group_id == UUID(group_id)
                )
            )
        )
        assert {member.role for member in memberships} == {"admin", "contributor"}
        registered = await db.scalar(select(User))
        assert registered is not None
        assert registered.role == UserRole.EMPLOYEE


@pytest.mark.asyncio
async def test_invite_expiry_revocation_replay_limits_and_import_idempotency(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "invite-host", "Invitation test")
    group_id = group["id"]

    revoked = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("invite-host"),
        json={},
    )
    revoked_id = revoked.json()["id"]
    assert (
        await client.delete(
            f"/api/v1/guest/groups/{group_id}/invitations/{revoked_id}",
            headers=bearer("invite-host"),
        )
    ).status_code == 204
    preview = await client.post(
        "/api/v1/guest/invitations/preview",
        headers=bearer("invite-joiner"),
        json={"token": revoked.json()["token"]},
    )
    assert preview.json() == {"valid": False}
    replay = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("invite-joiner"),
        json={"token": revoked.json()["token"], "display_name": "Guest"},
    )
    assert replay.status_code == 404

    expired = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("invite-host"),
        json={"expires_in_hours": 1},
    )
    async with session_factory() as db:
        invitation = await db.scalar(
            select(GuestGroupInvitation).where(
                GuestGroupInvitation.id == UUID(expired.json()["id"])
            )
        )
        invitation.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        await db.commit()
    expired_preview = await client.post(
        "/api/v1/guest/invitations/preview",
        headers=bearer("invite-joiner"),
        json={"token": expired.json()["token"]},
    )
    assert expired_preview.json() == {"valid": False}
    expired_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("invite-joiner"),
        json={"token": expired.json()["token"], "display_name": "Guest"},
    )
    assert expired_join.status_code == 404

    import_data = {
        "entries": [
            {
                "kind": "interact_session",
                "title": "Imported branch",
                "client_import_key": "stable-import-0001",
                "share_with_group": True,
                "data": {
                    "participants": [{"id": "participant-1"}],
                    "questions": [
                        {
                            "id": "question-1",
                            "answers": [
                                {
                                    "participant_id": "participant-1",
                                    "follow_up": {"id": "question-2"},
                                }
                            ],
                        }
                    ],
                },
            }
        ]
    }
    first = await client.post(
        f"/api/v1/guest/groups/{group_id}/import",
        headers=bearer("invite-host"),
        json=import_data,
    )
    retry = await client.post(
        f"/api/v1/guest/groups/{group_id}/import",
        headers=bearer("invite-host"),
        json=import_data,
    )
    assert first.status_code == retry.status_code == 200
    assert first.json()[0]["id"] == retry.json()[0]["id"]
    assert retry.json()[0]["data"] == import_data["entries"][0]["data"]
    async with session_factory() as db:
        assert await db.scalar(
            select(func.count(GuestGroupEntry.id)).where(
                GuestGroupEntry.group_id == UUID(group_id)
            )
        ) == 1

    monkeypatch.setitem(guest_service.GUEST_RATE_LIMITS, "search", (1, 60))
    first_search = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("invite-host"),
        params={"query": "Imported"},
    )
    assert first_search.status_code == 200
    limited_search = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("invite-host"),
        params={"query": "Imported"},
    )
    assert limited_search.status_code == 429
