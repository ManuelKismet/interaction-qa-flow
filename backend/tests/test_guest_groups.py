from datetime import datetime, timedelta, timezone
from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.api import dependencies
from app.api.dependencies import enforce_tenant_scope, get_development_identity
from app.main import app
from app.maintenance import guest_retention
from app.models.guest import (
    GuestGroupAdminTransfer,
    GuestGroup,
    GuestGroupEntry,
    GuestGroupEntryRevision,
    GuestGroupInvitation,
    GuestGroupMembership,
)
from app.models import FirebaseUidMapping, Organisation, User, UserRole
from app.repositories.guest import GuestRepository
from app.services import guest as guest_service

PROJECT_ID = "intqaflow-dev"


def bearer(
    uid: str,
    provider: str = "password",
    *,
    email_verified: bool | None = None,
) -> dict[str, str]:
    verified = (
        provider != "anonymous" if email_verified is None else email_verified
    )
    token = f"test-{provider}-{uid}~{int(verified)}"
    return {"Authorization": "".join(("Bear", "er ", token))}


def install_test_tokens(monkeypatch) -> None:
    def verify(token: str, _settings) -> dict[str, object]:
        token, verified = token.rsplit("~", 1)
        _, provider, uid = token.split("-", 2)
        return {
            "aud": PROJECT_ID,
            "iss": f"https://securetoken.google.com/{PROJECT_ID}",
            "sub": uid,
            "firebase": {"sign_in_provider": provider},
            "email_verified": verified == "1",
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
async def test_all_group_routes_require_verified_registered_identity(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    group_id = "00000000-0000-0000-0000-000000000001"
    entry_id = "00000000-0000-0000-0000-000000000002"
    member_id = "00000000-0000-0000-0000-000000000003"
    transfer_id = "00000000-0000-0000-0000-000000000004"
    invitation_id = "00000000-0000-0000-0000-000000000005"
    invitation_token = "x" * 40
    knowledge = {
        "kind": "knowledge",
        "title": "Policy",
        "data": {"body": "Local review only"},
    }
    routes = [
        ("GET", "/api/v1/guest/groups", None, None),
        ("GET", "/api/v1/guest/groups/archived", None, None),
        (
            "POST",
            "/api/v1/guest/groups",
            {"name": "Policy group", "display_name": "Reviewer"},
            None,
        ),
        ("GET", f"/api/v1/guest/groups/{group_id}", None, None),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/invitations",
            {"role": "viewer", "expires_in_hours": 24},
            None,
        ),
        ("GET", f"/api/v1/guest/groups/{group_id}/invitations", None, None),
        (
            "DELETE",
            f"/api/v1/guest/groups/{group_id}/invitations/{invitation_id}",
            None,
            None,
        ),
        (
            "POST",
            "/api/v1/guest/invitations/preview",
            {"token": invitation_token},
            None,
        ),
        (
            "POST",
            "/api/v1/guest/invitations/join",
            {"token": invitation_token, "display_name": "Reviewer"},
            None,
        ),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/members/{member_id}/approve",
            None,
            None,
        ),
        (
            "PATCH",
            f"/api/v1/guest/groups/{group_id}/members/{member_id}/role",
            {"role": "viewer"},
            None,
        ),
        (
            "DELETE",
            f"/api/v1/guest/groups/{group_id}/members/{member_id}",
            None,
            None,
        ),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/transfer-administration",
            None,
            {"member_id": member_id},
        ),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}/accept",
            None,
            None,
        ),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}/decline",
            None,
            None,
        ),
        (
            "DELETE",
            f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}",
            None,
            None,
        ),
        ("POST", f"/api/v1/guest/groups/{group_id}/archive", None, None),
        ("POST", f"/api/v1/guest/groups/{group_id}/restore", None, None),
        ("DELETE", f"/api/v1/guest/groups/{group_id}/permanent", None, None),
        ("DELETE", f"/api/v1/guest/groups/{group_id}", None, None),
        ("GET", f"/api/v1/guest/groups/{group_id}/entries", None, None),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/entries",
            knowledge,
            None,
        ),
        (
            "POST",
            f"/api/v1/guest/groups/{group_id}/import",
            {"entries": [knowledge]},
            None,
        ),
        (
            "GET",
            f"/api/v1/guest/groups/{group_id}/entries/{entry_id}",
            None,
            None,
        ),
        (
            "PATCH",
            f"/api/v1/guest/groups/{group_id}/entries/{entry_id}",
            {"expected_revision": 1, "title": "Updated policy"},
            None,
        ),
        (
            "DELETE",
            f"/api/v1/guest/groups/{group_id}/entries/{entry_id}",
            None,
            None,
        ),
        (
            "GET",
            f"/api/v1/guest/groups/{group_id}/entries/{entry_id}/history",
            None,
            None,
        ),
        (
            "GET",
            f"/api/v1/guest/groups/{group_id}/entries/{entry_id}/export",
            None,
            None,
        ),
    ]

    missing_token = await client.get("/api/v1/guest/groups")
    invalid_token = await client.get(
        "/api/v1/guest/groups",
        headers={"Authorization": "Bearer " + "invalid"},
    )
    assert missing_token.status_code == 401
    assert invalid_token.status_code == 401

    for method, path, payload, params in routes:
        for identity, detail in (
            (
                bearer("registered-shape", "anonymous"),
                "A registered account is required to use Groups",
            ),
            (
                bearer(
                    "unverified-registered",
                    "password",
                    email_verified=False,
                ),
                "Verify your email address to use Groups",
            ),
        ):
            response = await client.request(
                method,
                path,
                headers=identity,
                json=payload,
                params=params,
            )
            assert response.status_code == 403, (method, path, response.text)
            assert response.json() == {"detail": detail}

    account_state = await client.get(
        "/api/v1/account/state",
        headers=bearer("preserved-anonymous-account-state", "anonymous"),
    )
    assert account_state.status_code == 200
    assert account_state.json() == {"status": "shared_guest"}


@pytest.mark.asyncio
async def test_anonymous_same_uid_cannot_reuse_registered_group_access(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    owner_uid = "registered-group-owner"
    member_uid = "registered-group-member"
    group = await make_group(client, owner_uid, "Registered group")
    group_id = group["id"]

    invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer(owner_uid),
        json={"role": "contributor", "expires_in_hours": 24},
    )
    assert invitation.status_code == 200, invitation.text
    join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer(member_uid),
        json={
            "token": invitation.json()["token"],
            "display_name": "Registered member",
        },
    )
    assert join.status_code == 200, join.text
    approved = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{join.json()['id']}/approve",
        headers=bearer(owner_uid),
    )
    assert approved.status_code == 200, approved.text

    anonymous_owner = bearer(owner_uid, "anonymous")
    anonymous_member = bearer(member_uid, "anonymous")
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=anonymous_owner,
        )
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=anonymous_member,
        )
    ).status_code == 403
    denied_write = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=anonymous_member,
        json={
            "kind": "knowledge",
            "title": "Anonymous write",
            "data": {"body": "Must be denied"},
        },
    )
    assert denied_write.status_code == 403
    denied_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=anonymous_owner,
        json={"role": "viewer", "expires_in_hours": 24},
    )
    assert denied_invitation.status_code == 403

    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=bearer(owner_uid),
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=bearer(member_uid),
        )
    ).status_code == 200
    allowed_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer(owner_uid),
        json={"role": "viewer", "expires_in_hours": 24},
    )
    assert allowed_invitation.status_code == 200, allowed_invitation.text
    allowed_write = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer(member_uid),
        json={
            "kind": "knowledge",
            "title": "Registered write",
            "data": {"body": "Allowed for the registered member"},
        },
    )
    assert allowed_write.status_code == 201, allowed_write.text


@pytest.mark.asyncio
async def test_group_invites_roles_removal_and_group_boundary(app_client, monkeypatch) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    owner = await make_group(client, "guest-owner", "Field research")
    group_id = owner["id"]
    linked_owner = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("guest-owner", "password"),
    )
    assert linked_owner.status_code == 200
    assert linked_owner.json()["role"] == "admin"
    linked_owner_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("guest-owner", "password"),
        json={"role": "viewer", "expires_in_hours": 12},
    )
    assert linked_owner_invitation.status_code == 200
    assert (
        await client.delete(
            f"/api/v1/guest/groups/{group_id}/invitations/"
            f"{linked_owner_invitation.json()['id']}",
            headers=bearer("guest-owner", "password"),
        )
    ).status_code == 204
    identity_override = app.dependency_overrides.pop(get_development_identity)
    try:
        unmapped_identity = await client.get(
            "/api/v1/auth/me",
            headers=bearer("guest-owner", "password"),
        )
    finally:
        app.dependency_overrides[get_development_identity] = identity_override
    assert unmapped_identity.status_code == 401
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
        json={"expected_revision": 1, "title": "Updated password policy"},
    )
    assert changed.status_code == 403
    admin_edit = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-owner"),
        json={"expected_revision": 1, "title": "Admin-reviewed password policy"},
    )
    assert admin_edit.status_code == 200
    changed_by_author = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-joiner"),
        json={"expected_revision": 2, "title": "Updated password policy"},
    )
    assert changed_by_author.status_code == 200

    first_edit = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-joiner"),
        json={"expected_revision": 3, "title": "First concurrent edit"},
    )
    assert first_edit.status_code == 200
    assert first_edit.json()["revision"] == 4
    stale_edit = await client.patch(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-owner"),
        json={"expected_revision": 3, "title": "Stale concurrent edit"},
    )
    assert stale_edit.status_code == 409
    latest = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}",
        headers=bearer("guest-owner"),
    )
    assert latest.status_code == 200
    assert latest.json()["title"] == "First concurrent edit"
    assert latest.json()["revision"] == 4

    history = await client.get(
        f"/api/v1/guest/groups/{group_id}/entries/{knowledge.json()['id']}/history",
        headers=bearer("guest-owner"),
    )
    assert [item["revision"] for item in history.json()] == [1, 2, 3, 4]
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
    assert transfer.json()["status"] == "pending"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=bearer("transfer-host"),
        )
    ).json()["role"] == "admin"
    recipient_detail = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("transfer-viewer"),
    )
    pending_transfer = recipient_detail.json()["pending_admin_transfer"]
    assert pending_transfer["is_target"] is True
    accepted_transfer = await client.post(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/"
        f"{transfer.json()['id']}/accept",
        headers=bearer("transfer-viewer"),
    )
    assert accepted_transfer.status_code == 200, accepted_transfer.text
    assert accepted_transfer.json()["status"] == "accepted"
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
        "/api/v1/auth/me", headers=bearer("new-anonymous-user", "anonymous")
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
        json={"name": "Registered group", "display_name": "Org user"},
    )
    assert registered_create.status_code == 201
    assert registered_create.json()["role"] == "admin"

    unverified_create = await client.post(
        "/api/v1/guest/groups",
        headers=bearer(
            "unverified-registered", "password", email_verified=False
        ),
        json={"name": "Unverified group", "display_name": "Unverified user"},
    )
    assert unverified_create.status_code == 403

    registered_group = registered_create.json()
    registered_invitation = await client.post(
        f"/api/v1/guest/groups/{registered_group['id']}/invitations",
        headers=bearer("registered-org-user", "password"),
        json={"role": "contributor", "expires_in_hours": 12},
    )
    assert registered_invitation.status_code == 200
    registered_join_payload = {
        "token": registered_invitation.json()["token"],
        "display_name": "Verified joiner",
    }
    rejected_identity_header = await client.post(
        "/api/v1/guest/invitations/join",
        headers={
            **bearer(
                "verified-registered-joiner", "google.com", email_verified=True
            ),
            "X-User-ID": "caller-selected-user",
        },
        json=registered_join_payload,
    )
    assert rejected_identity_header.status_code == 400
    assert rejected_identity_header.json() == {
        "detail": "Caller-selected identity and organisation headers are not accepted"
    }
    pending_registered = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer(
            "verified-registered-joiner", "google.com", email_verified=True
        ),
        json=registered_join_payload,
    )
    assert pending_registered.status_code == 200
    assert pending_registered.json()["status"] == "pending"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{registered_group['id']}",
            headers=bearer("verified-registered-joiner", "google.com"),
        )
    ).status_code == 404
    unverified_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer(
            "unverified-joiner", "password", email_verified=False
        ),
        json={
            "token": registered_invitation.json()["token"],
            "display_name": "Unverified joiner",
        },
    )
    assert unverified_join.status_code == 403
    approve_registered = await client.post(
        f"/api/v1/guest/groups/{registered_group['id']}/members/"
        f"{pending_registered.json()['id']}/approve",
        headers=bearer("registered-org-user", "password"),
    )
    assert approve_registered.status_code == 200
    assert approve_registered.json()["status"] == "active"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{registered_group['id']}",
            headers=bearer("verified-registered-joiner", "google.com"),
        )
    ).status_code == 200
    assert (
        await client.get(
            "/api/v1/auth/me",
            headers=bearer("verified-registered-joiner", "google.com"),
        )
    ).status_code == 401
    async with session_factory() as db:
        registered_user = await db.scalar(
            select(User).where(
                User.id == UUID("00000000-0000-0000-0000-000000000002")
            )
        )
        assert registered_user is not None
        registered_user.role = UserRole.ADMIN
        await db.commit()
    org_admin_has_no_implicit_group_access = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("registered-org-user", "password"),
    )
    assert org_admin_has_no_implicit_group_access.status_code == 404
    linked_group_admin = await client.get(
        f"/api/v1/guest/groups/{registered_group['id']}",
        headers=bearer("registered-org-user", "password"),
    )
    assert linked_group_admin.status_code == 200
    assert linked_group_admin.json()["role"] == "admin"

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
        assert registered.role == UserRole.ADMIN


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


@pytest.mark.asyncio
async def test_archive_retains_group_data_and_restores_only_same_admin_uid(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "archive-owner", "Recoverable group")
    group_id = group["id"]
    invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archive-owner"),
        json={"role": "viewer"},
    )
    unused_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archive-owner"),
        json={"role": "contributor"},
    )
    removed_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archive-owner"),
        json={"role": "viewer"},
    )
    pending_member = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("pending-member"),
        json={
            "token": invitation.json()["token"],
            "display_name": "Pending member",
        },
    )
    removed_member = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("removed-member"),
        json={
            "token": removed_invitation.json()["token"],
            "display_name": "Removed member",
        },
    )
    assert removed_member.status_code == 200
    approved_removed_member = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/"
        f"{removed_member.json()['id']}/approve",
        headers=bearer("archive-owner"),
    )
    assert approved_removed_member.status_code == 200
    removed = await client.delete(
        f"/api/v1/guest/groups/{group_id}/members/{removed_member.json()['id']}",
        headers=bearer("archive-owner"),
    )
    assert removed.status_code == 204
    content = await client.post(
        f"/api/v1/guest/groups/{group_id}/entries",
        headers=bearer("archive-owner"),
        json={
            "kind": "knowledge",
            "title": "Retained entry",
            "data": {"answer": "Still retained"},
        },
    )
    assert pending_member.status_code == 200
    assert content.status_code == 201

    archived = await client.post(
        f"/api/v1/guest/groups/{group_id}/archive",
        headers=bearer("archive-owner"),
    )
    assert archived.status_code == 200, archived.text
    archived_at = datetime.fromisoformat(archived.json()["archived_at"])
    restore_until = datetime.fromisoformat(archived.json()["restore_until"])
    assert restore_until - archived_at == timedelta(days=30)
    assert (
        await client.get("/api/v1/guest/groups", headers=bearer("archive-owner"))
    ).json() == []
    archived_groups = await client.get(
        "/api/v1/guest/groups/archived", headers=bearer("archive-owner")
    )
    assert archived_groups.status_code == 200
    assert archived_groups.json()[0]["can_restore"] is True
    assert archived_groups.json()[0]["can_delete"] is True
    assert archived_groups.json()[0]["id"] == group_id
    preview = await client.post(
        "/api/v1/guest/invitations/preview",
        headers=bearer("invitee"),
        json={"token": unused_invitation.json()["token"]},
    )
    assert preview.json() == {"valid": False}
    archived_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("archived-invitee"),
        json={
            "token": unused_invitation.json()["token"],
            "display_name": "Archived invitee",
        },
    )
    assert archived_join.status_code == 404
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}",
            headers=bearer("archive-owner"),
        )
    ).status_code == 404

    restore_as_other_uid = await client.post(
        f"/api/v1/guest/groups/{group_id}/restore",
        headers=bearer("other-account", "password"),
    )
    assert restore_as_other_uid.status_code == 403
    restored = await client.post(
        f"/api/v1/guest/groups/{group_id}/restore",
        headers=bearer("archive-owner", "password"),
    )
    assert restored.status_code == 200, restored.text
    assert restored.json()["role"] == "admin"
    group_detail = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("archive-owner"),
    )
    restored_pending = next(
        item
        for item in group_detail.json()["members"]
        if item["id"] == pending_member.json()["id"]
    )
    assert restored_pending["status"] == "pending"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}/entries",
            headers=bearer("archive-owner"),
        )
    ).json()[0]["title"] == "Retained entry"
    assert (
        await client.get(
            f"/api/v1/guest/groups/{group_id}/invitations",
            headers=bearer("archive-owner"),
        )
    ).json() == []
    async with session_factory() as db:
        stored_group = await db.get(GuestGroup, UUID(group_id))
        assert stored_group is not None
        assert stored_group.archived_at is None
        assert stored_group.archived_by_uid is None
        restored_removed = await db.get(
            GuestGroupMembership, UUID(removed_member.json()["id"])
        )
        assert restored_removed is not None
        assert restored_removed.status == "removed"
        assert (
            await db.scalar(
                select(func.count(GuestGroupEntry.id)).where(
                    GuestGroupEntry.group_id == UUID(group_id)
                )
            )
            == 1
        )
        stored_invitation = await db.get(
            GuestGroupInvitation, UUID(unused_invitation.json()["id"])
        )
        assert stored_invitation is not None
        assert stored_invitation.revoked_at is not None


@pytest.mark.asyncio
async def test_archive_recovery_expiry_and_cleanup_exclusion(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "archive-expiry", "Archived expiry")
    group_id = group["id"]
    archived = await client.post(
        f"/api/v1/guest/groups/{group_id}/archive",
        headers=bearer("archive-expiry"),
    )
    assert archived.status_code == 200
    async with session_factory() as session:
        stored_group = await session.get(GuestGroup, UUID(group_id))
        stored_group.archived_at = datetime.now(timezone.utc) - timedelta(days=31)
        stored_group.expires_at = datetime.now(timezone.utc) - timedelta(days=1)
        await session.commit()
    expired_restore = await client.post(
        f"/api/v1/guest/groups/{group_id}/restore",
        headers=bearer("archive-expiry", "password"),
    )
    assert expired_restore.status_code == 410
    result = await guest_retention.cleanup_expired_guest_groups(
        session_factory,
        cutoff=datetime.now(timezone.utc),
        apply=True,
    )
    assert result["candidate_groups"] == 0
    async with session_factory() as session:
        retained_group = await session.get(GuestGroup, UUID(group_id))
        assert retained_group is not None
        assert retained_group.archived_at is not None


@pytest.mark.asyncio
async def test_permanent_delete_requires_archiving_admin_and_removes_group_dependents(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "original-owner", "Shared group")
    group_id = UUID(group["id"])
    transfer_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("original-owner"),
        json={"role": "viewer"},
    )
    archived_admin_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("archived-admin"),
        json={
            "token": transfer_invitation.json()["token"],
            "display_name": "Current admin",
        },
    )
    assert archived_admin_join.status_code == 200
    admin_approval = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/"
        f"{archived_admin_join.json()['id']}/approve",
        headers=bearer("original-owner"),
    )
    assert admin_approval.status_code == 200
    transfer = await client.post(
        f"/api/v1/guest/groups/{group_id}/transfer-administration",
        headers=bearer("original-owner"),
        params={"member_id": archived_admin_join.json()["id"]},
    )
    assert transfer.status_code == 200
    accepted_transfer = await client.post(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/"
        f"{transfer.json()['id']}/accept",
        headers=bearer("archived-admin"),
    )
    assert accepted_transfer.status_code == 200

    removed_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archived-admin"),
        json={"role": "viewer"},
    )
    removed_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("removed-member"),
        json={
            "token": removed_invitation.json()["token"],
            "display_name": "Removed member",
        },
    )
    assert removed_join.status_code == 200
    removed_approval = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{removed_join.json()['id']}/approve",
        headers=bearer("archived-admin"),
    )
    assert removed_approval.status_code == 200
    removed = await client.delete(
        f"/api/v1/guest/groups/{group_id}/members/{removed_join.json()['id']}",
        headers=bearer("archived-admin"),
    )
    assert removed.status_code == 204
    pending_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archived-admin"),
        json={"role": "viewer"},
    )
    pending_join = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("pending-member"),
        json={
            "token": pending_invitation.json()["token"],
            "display_name": "Pending member",
        },
    )
    assert pending_join.status_code == 200
    outstanding_invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("archived-admin"),
        json={"role": "viewer"},
    )
    assert outstanding_invitation.status_code == 200

    async with session_factory() as session:
        stored_group = await session.get(GuestGroup, group_id)
        creator_membership = await session.scalar(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.firebase_uid == "original-owner",
            )
        )
        archived_admin = await session.scalar(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.firebase_uid == "archived-admin",
            )
        )
        pending_member = await session.scalar(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.firebase_uid == "pending-member",
            )
        )
        removed_member = await session.scalar(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.firebase_uid == "removed-member",
            )
        )
        assert creator_membership.role == "contributor"
        assert archived_admin.role == "admin"
        assert pending_member.status == "pending"
        assert removed_member.status == "removed"
        entry = GuestGroupEntry(
            group_id=group_id,
            kind="knowledge",
            title="Retained content",
            data={"answer": "shared"},
            created_by_uid="original-owner",
            updated_by_uid="original-owner",
            revision=2,
        )
        session.add(entry)
        await session.flush()
        revision = GuestGroupEntryRevision(
            entry_id=entry.id,
            edited_by_uid="original-owner",
            title="Previous content",
            data={"answer": "old"},
            revision=1,
        )
        session.add(revision)
        await session.flush()
        revision_id = revision.id
        await session.commit()
    archived = await client.post(
        f"/api/v1/guest/groups/{group_id}/archive",
        headers=bearer("archived-admin"),
    )
    assert archived.status_code == 200
    async with session_factory() as session:
        stored_group = await session.get(GuestGroup, group_id)
        stored_group.archived_at = datetime.now(timezone.utc) - timedelta(days=31)
        await session.commit()

    path = f"/api/v1/guest/groups/{group_id}/permanent"
    archived_listing = await client.get(
        "/api/v1/guest/groups/archived", headers=bearer("archived-admin")
    )
    assert archived_listing.status_code == 200
    assert archived_listing.json()[0]["can_restore"] is False
    assert archived_listing.json()[0]["can_delete"] is True
    assert (await client.delete(path)).status_code == 401
    assert (
        await client.delete(path, headers=bearer("original-owner"))
    ).status_code == 403
    assert (await client.delete(path, headers=bearer("outsider"))).status_code == 403

    async with session_factory() as session:
        current_admin = await session.get(GuestGroupMembership, archived_admin.id)
        current_admin.role = "contributor"
        replacement_admin = GuestGroupMembership(
            group_id=group_id,
            firebase_uid="replacement-admin",
            display_name="Replacement admin",
            role="admin",
            status="active",
            approved_by_uid="original-owner",
        )
        session.add(replacement_admin)
        await session.commit()
    assert (
        await client.delete(path, headers=bearer("archived-admin"))
    ).status_code == 403
    assert (
        await client.delete(path, headers=bearer("replacement-admin"))
    ).status_code == 403
    assert (
        await client.delete(path, headers=bearer("pending-member"))
    ).status_code == 403
    assert (
        await client.delete(path, headers=bearer("removed-member"))
    ).status_code == 403
    async with session_factory() as session:
        former_admin = await session.get(GuestGroupMembership, archived_admin.id)
        former_admin.role = "admin"
        await session.commit()

    active_group = await make_group(client, "active-owner", "Still active")
    active_delete = await client.delete(
        f"/api/v1/guest/groups/{active_group['id']}/permanent",
        headers=bearer("active-owner"),
    )
    assert active_delete.status_code == 404
    async with session_factory() as session:
        assert await session.get(GuestGroup, UUID(active_group["id"])) is not None

    deleted = await client.delete(path, headers=bearer("archived-admin"))
    assert deleted.status_code == 204
    assert (
        await client.delete(path, headers=bearer("archived-admin"))
    ).status_code == 404
    async with session_factory() as session:
        assert await session.get(GuestGroup, group_id) is None
        for model in (
            GuestGroupMembership,
            GuestGroupInvitation,
            GuestGroupAdminTransfer,
            GuestGroupEntry,
        ):
            assert await session.scalar(
                select(func.count()).select_from(model).where(
                    model.group_id == group_id
                )
            ) == 0
        assert await session.get(GuestGroupEntryRevision, revision_id) is None


@pytest.mark.asyncio
async def test_permanent_delete_rolls_back_all_dependents_on_commit_failure(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "rollback-owner", "Rollback group")
    group_id = UUID(group["id"])
    async with session_factory() as session:
        stored_group = await session.get(GuestGroup, group_id)
        stored_group.archived_at = datetime.now(timezone.utc)
        stored_group.archived_by_uid = "rollback-owner"
        entry = GuestGroupEntry(
            group_id=group_id,
            kind="knowledge",
            title="Must survive rollback",
            data={"answer": "still here"},
            created_by_uid="rollback-owner",
            updated_by_uid="rollback-owner",
            revision=1,
        )
        session.add(entry)
        await session.flush()
        member = GuestGroupMembership(
            group_id=group_id,
            firebase_uid="rollback-member",
            display_name="Rollback member",
            role="viewer",
            status="active",
            approved_by_uid="rollback-owner",
        )
        session.add(member)
        await session.flush()
        invitation = GuestGroupInvitation(
            group_id=group_id,
            token_hash=group_id.hex * 2,
            role="viewer",
            created_by_uid="rollback-owner",
            expires_at=datetime.now(timezone.utc) + timedelta(days=1),
        )
        transfer = GuestGroupAdminTransfer(
            group_id=group_id,
            requested_by_uid="rollback-owner",
            target_membership_id=member.id,
            status="declined",
            expires_at=datetime.now(timezone.utc) + timedelta(days=1),
        )
        session.add_all([invitation, transfer])
        session.add(
            GuestGroupEntryRevision(
                entry_id=entry.id,
                edited_by_uid="rollback-owner",
                title=entry.title,
                data=entry.data,
                revision=1,
            )
        )
        await session.commit()

    async def fail_commit(_repository) -> None:
        raise RuntimeError("synthetic commit failure")

    monkeypatch.setattr(GuestRepository, "commit", fail_commit)
    async with session_factory() as session:
        with pytest.raises(RuntimeError, match="synthetic commit failure"):
            await guest_service.GuestService(session).permanently_delete_archived_group(
                group_id, "rollback-owner"
            )

    async with session_factory() as session:
        assert await session.get(GuestGroup, group_id) is not None
        assert await session.scalar(
            select(func.count(GuestGroupEntry.id)).where(
                GuestGroupEntry.group_id == group_id
            )
        ) == 1
        assert await session.scalar(
            select(func.count(GuestGroupEntryRevision.id))
            .join(
                GuestGroupEntry,
                GuestGroupEntry.id == GuestGroupEntryRevision.entry_id,
            )
            .where(GuestGroupEntry.group_id == group_id)
        ) == 1
        assert await session.scalar(
            select(func.count(GuestGroupMembership.id)).where(
                GuestGroupMembership.group_id == group_id
            )
        ) == 2
        assert await session.scalar(
            select(func.count(GuestGroupInvitation.id)).where(
                GuestGroupInvitation.group_id == group_id
            )
        ) == 1
        assert await session.scalar(
            select(func.count(GuestGroupAdminTransfer.id)).where(
                GuestGroupAdminTransfer.group_id == group_id
            )
        ) == 1


@pytest.mark.asyncio
async def test_permanent_delete_is_rate_limited(app_client, monkeypatch) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    first = await make_group(client, "limited-owner", "First archived group")
    second = await make_group(client, "limited-owner", "Second archived group")
    for group in (first, second):
        archived = await client.post(
            f"/api/v1/guest/groups/{group['id']}/archive",
            headers=bearer("limited-owner"),
        )
        assert archived.status_code == 200
    monkeypatch.setitem(guest_service.GUEST_RATE_LIMITS, "permanent_delete", (1, 3600))

    first_delete = await client.delete(
        f"/api/v1/guest/groups/{first['id']}/permanent",
        headers=bearer("limited-owner"),
    )
    second_delete = await client.delete(
        f"/api/v1/guest/groups/{second['id']}/permanent",
        headers=bearer("limited-owner"),
    )
    assert first_delete.status_code == 204
    assert second_delete.status_code == 429
    async with session_factory() as session:
        assert await session.get(GuestGroup, UUID(second["id"])) is not None


@pytest.mark.asyncio
async def test_expired_admin_transfer_does_not_change_roles(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "transfer-expiry-owner", "Transfer expiry")
    group_id = group["id"]
    invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-expiry-owner"),
        json={"role": "viewer"},
    )
    joined = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("transfer-expiry-target"),
        json={
            "token": invitation.json()["token"],
            "display_name": "Target",
        },
    )
    approved = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{joined.json()['id']}/approve",
        headers=bearer("transfer-expiry-owner"),
    )
    assert approved.status_code == 200
    proposal = await client.post(
        f"/api/v1/guest/groups/{group_id}/transfer-administration",
        headers=bearer("transfer-expiry-owner"),
        params={"member_id": joined.json()["id"]},
    )
    assert proposal.status_code == 200
    async with session_factory() as session:
        transfer = await session.get(
            guest_service.GuestGroupAdminTransfer, UUID(proposal.json()["id"])
        )
        transfer.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        await session.commit()

    expired = await client.post(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/"
        f"{proposal.json()['id']}/accept",
        headers=bearer("transfer-expiry-target"),
    )
    assert expired.status_code == 409
    owner = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("transfer-expiry-owner"),
    )
    target = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("transfer-expiry-target"),
    )
    assert owner.json()["role"] == "admin"
    assert target.json()["role"] == "viewer"
    async with session_factory() as session:
        transfer = await session.get(
            guest_service.GuestGroupAdminTransfer, UUID(proposal.json()["id"])
        )
        assert transfer.status == "expired"


@pytest.mark.asyncio
async def test_transfer_decline_cancel_and_removed_recipient_preserve_admin(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "transfer-lifecycle-owner", "Transfer lifecycle")
    group_id = group["id"]
    invitation = await client.post(
        f"/api/v1/guest/groups/{group_id}/invitations",
        headers=bearer("transfer-lifecycle-owner"),
        json={"role": "viewer"},
    )
    joined = await client.post(
        "/api/v1/guest/invitations/join",
        headers=bearer("transfer-lifecycle-target"),
        json={
            "token": invitation.json()["token"],
            "display_name": "Transfer target",
        },
    )
    approved = await client.post(
        f"/api/v1/guest/groups/{group_id}/members/{joined.json()['id']}/approve",
        headers=bearer("transfer-lifecycle-owner"),
    )
    assert approved.status_code == 200

    declined_request = await client.post(
        f"/api/v1/guest/groups/{group_id}/transfer-administration",
        headers=bearer("transfer-lifecycle-owner"),
        params={"member_id": joined.json()["id"]},
    )
    transfer_id = declined_request.json()["id"]
    declined = await client.post(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}/decline",
        headers=bearer("transfer-lifecycle-target"),
    )
    assert declined.status_code == 200
    assert declined.json()["status"] == "declined"

    pending_request = await client.post(
        f"/api/v1/guest/groups/{group_id}/transfer-administration",
        headers=bearer("transfer-lifecycle-owner"),
        params={"member_id": joined.json()["id"]},
    )
    transfer_id = pending_request.json()["id"]
    removed = await client.delete(
        f"/api/v1/guest/groups/{group_id}/members/{joined.json()['id']}",
        headers=bearer("transfer-lifecycle-owner"),
    )
    assert removed.status_code == 204
    stale_acceptance = await client.post(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}/accept",
        headers=bearer("transfer-lifecycle-target"),
    )
    assert stale_acceptance.status_code == 404

    cancelled = await client.delete(
        f"/api/v1/guest/groups/{group_id}/admin-transfers/{transfer_id}",
        headers=bearer("transfer-lifecycle-owner"),
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"
    owner = await client.get(
        f"/api/v1/guest/groups/{group_id}",
        headers=bearer("transfer-lifecycle-owner"),
    )
    assert owner.status_code == 200
    assert owner.json()["role"] == "admin"
    async with session_factory() as session:
        transfer = await session.get(
            guest_service.GuestGroupAdminTransfer, UUID(transfer_id)
        )
        assert transfer is not None
        assert transfer.status == "cancelled"
