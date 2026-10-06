import asyncio
from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.api import dependencies
from app.main import app
from app.models.personal_workspace import PersonalWorkspaceItem

PROJECT_ID = "intqaflow-dev"


def bearer(uid: str, provider: str = "password", verified: bool = True) -> dict[str, str]:
    token = f"personal-{provider}-{uid}~{int(verified)}"
    return {"Authorization": "Bearer " + token}


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


def knowledge(source_key: str = "knowledge:local-id") -> dict:
    return {
        "kind": "knowledge",
        "source_key": source_key,
        "title": "Private answer",
        "data": {
            "id": source_key.split(":", 1)[1],
            "title": "Private answer",
            "body": "private search sentinel",
            "answer": "Only on this account",
        },
    }


@pytest.mark.asyncio
async def test_personal_workspace_is_verified_uid_private_and_idempotent(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    nested_session = {
        "kind": "interact_session",
        "source_key": "session:local-session",
        "title": "Private interview",
        "data": {
            "id": "local-session",
            "title": "Private interview",
            "participants": [{"id": "p1", "name": "Alice"}],
            "questions": [
                {
                    "id": "q1",
                    "text": "Question",
                    "scope": "shared",
                    "answers": [
                        {
                            "participant_id": "p1",
                            "body": "Private answer",
                            "follow_ups": [
                                {
                                    "id": "q2",
                                    "text": "Nested question",
                                    "scope": "participant",
                                    "answers": [],
                                }
                            ],
                        }
                    ],
                }
            ],
        },
    }
    template = {
        "kind": "template",
        "source_key": "template:local-template",
        "title": "Private template",
        "data": {
            "id": "local-template",
            "name": "Private template",
            "questions": [{"id": "root", "text": "Root", "follow_ups": []}],
        },
    }
    headers = bearer("verified-without-organisation")
    response = await client.post(
        "/api/v1/personal/items/import",
        headers=headers,
        json={"items": [knowledge(), nested_session, template]},
    )
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["created"] == [True, True, True]
    assert result["items"][1]["data"]["questions"][0]["answers"][0][
        "follow_ups"
    ][0]["text"] == "Nested question"

    replay = await client.post(
        "/api/v1/personal/items/import",
        headers=headers,
        json={
            "items": [
                knowledge(),
                {
                    **knowledge("knowledge:other"),
                    "data": {
                        **knowledge("knowledge:other")["data"],
                        "id": "other",
                    },
                },
            ]
        },
    )
    assert replay.status_code == 201, replay.text
    assert replay.json()["created"] == [False, True]
    assert replay.json()["items"][0]["data"]["answer"] == "Only on this account"

    listed = await client.get("/api/v1/personal/items", headers=headers)
    assert listed.status_code == 200
    assert {item["kind"] for item in listed.json()} == {
        "knowledge",
        "interact_session",
        "template",
    }
    item_id = UUID(result["items"][0]["id"])
    assert (await client.get("/api/v1/personal/items", headers=bearer("other"))).json() == []
    denied_update = await client.put(
        f"/api/v1/personal/items/{item_id}",
        headers=bearer("other"),
        json={
            "expected_revision": 1,
            "title": "Attempted overwrite",
            "data": knowledge()["data"],
        },
    )
    assert denied_update.status_code == 404
    hidden_delete = await client.delete(
        f"/api/v1/personal/items/{item_id}",
        headers=bearer("other"),
        params={"expected_revision": 1},
    )
    assert hidden_delete.status_code == 204
    assert len(
        (await client.get("/api/v1/personal/items", headers=headers)).json()
    ) == 4

    update_payload = {
        "expected_revision": 1,
        "title": "Updated privately",
        "data": {
            **knowledge()["data"],
            "title": "Updated privately",
        },
    }
    updated = await client.put(
        f"/api/v1/personal/items/{item_id}",
        headers=headers,
        json=update_payload,
    )
    assert updated.status_code == 200
    assert updated.json()["revision"] == 2
    replayed_update = await client.put(
        f"/api/v1/personal/items/{item_id}",
        headers=headers,
        json=update_payload,
    )
    assert replayed_update.status_code == 200
    assert replayed_update.json()["revision"] == 2
    conflict = await client.put(
        f"/api/v1/personal/items/{item_id}",
        headers=headers,
        json={
            "expected_revision": 1,
            "title": "Stale write",
            "data": knowledge()["data"],
        },
    )
    assert conflict.status_code == 409
    async with session_factory() as session:
        assert await session.scalar(
            select(PersonalWorkspaceItem).where(
                PersonalWorkspaceItem.firebase_uid == "other"
            )
        ) is None

    deleted = await client.delete(
        f"/api/v1/personal/items/{item_id}",
        headers=headers,
        params={"expected_revision": 1},
    )
    assert deleted.status_code == 409
    deleted = await client.delete(
        f"/api/v1/personal/items/{item_id}",
        headers=headers,
        params={"expected_revision": 2},
    )
    assert deleted.status_code == 204
    assert (
        await client.delete(
            f"/api/v1/personal/items/{item_id}",
            headers=headers,
            params={"expected_revision": 2},
        )
    ).status_code == 204
    remaining = await client.get("/api/v1/personal/items", headers=headers)
    assert {item["kind"] for item in remaining.json()} == {
        "knowledge",
        "interact_session",
        "template",
    }


@pytest.mark.asyncio
async def test_personal_workspace_denies_anonymous_unverified_and_overrides(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    for headers, detail in [
        (
            bearer("anonymous-owner", provider="anonymous"),
            "A registered account is required to use personal storage.",
        ),
        (
            bearer("unverified-user", verified=False),
            "Verify your email address before using personal storage.",
        ),
    ]:
        response = await client.get("/api/v1/personal/items", headers=headers)
        assert response.status_code == 403
        assert response.json()["detail"] == detail
        write = await client.post(
            "/api/v1/personal/items/import",
            headers=headers,
            json={"items": [knowledge()]},
        )
        assert write.status_code == 403

    invalid = await client.get("/api/v1/personal/items")
    assert invalid.status_code == 401
    malformed = await client.get(
        "/api/v1/personal/items",
        headers={"Authorization": "******"},
    )
    assert malformed.status_code == 401
    for header, value in [
        ("X-User-ID", "other-user"),
        ("X-Organisation-ID", "other-organisation"),
        ("X-User-Role", "admin"),
    ]:
        override = await client.post(
            "/api/v1/personal/items/import",
            headers={**bearer("verified-user"), header: value},
            json={"items": [knowledge()]},
        )
        assert override.status_code == 400
    body_override = await client.post(
        "/api/v1/personal/items/import",
        headers=bearer("verified-user"),
        json={
            "items": [
                {
                    **knowledge(),
                    "firebase_uid": "victim",
                }
            ]
        },
    )
    assert body_override.status_code == 422


@pytest.mark.asyncio
async def test_personal_workspace_validates_stable_ids_and_nested_content(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    install_test_tokens(monkeypatch)
    headers = bearer("content-validation")
    session = {
        "kind": "interact_session",
        "source_key": "interact_session:session-id",
        "title": "Session",
        "data": {
            "id": "session-id",
            "participants": [{"id": "participant-id", "name": "Alice"}],
            "questions": [
                {
                    "id": "question-id",
                    "text": "Question",
                    "answers": [{"participant_id": "participant-id", "body": "Answer"}],
                }
            ],
        },
    }
    template = {
        "kind": "template",
        "source_key": "template:template-id",
        "title": "Template",
        "data": {
            "id": "template-id",
            "name": "Template",
            "participant_slots": [{"id": "slot-id", "label": "Participant 1"}],
            "questions": [{"id": "question-id", "text": "Question"}],
        },
    }
    for item in [
        {**knowledge(), "data": {**knowledge()["data"], "id": "different-id"}},
        {**session, "data": {**session["data"], "participants": [{"name": "Alice"}]}},
        {
            **template,
            "data": {
                **template["data"],
                "questions": [
                    {
                        "id": "question-id",
                        "text": "Question",
                        "answers": [
                            {
                                "participant_slot": "slot-id",
                                "follow_ups": [{"text": "Missing ID"}],
                            }
                        ],
                    }
                ],
            },
        },
    ]:
        response = await client.post(
            "/api/v1/personal/items/import",
            headers=headers,
            json={"items": [item]},
        )
        assert response.status_code == 422

    valid_items = [knowledge(), session, template]
    imported = await client.post(
        "/api/v1/personal/items/import",
        headers=headers,
        json={"items": valid_items},
    )
    assert imported.status_code == 201, imported.text
    assert [item["source_key"] for item in imported.json()["items"]] == [
        item["source_key"] for item in valid_items
    ]

    for record in imported.json()["items"]:
        updated_data = record["data"]
        if record["kind"] == "knowledge":
            updated_data["id"] = "changed-id"
        elif record["kind"] == "interact_session":
            updated_data["questions"] = [{"text": "Missing question ID"}]
        else:
            updated_data["questions"] = [{"id": "question-id"}]
        response = await client.put(
            f"/api/v1/personal/items/{record['id']}",
            headers=headers,
            json={
                "expected_revision": 1,
                "title": record["title"],
                "data": updated_data,
            },
        )
        assert response.status_code == 422


@pytest.mark.asyncio
async def test_personal_import_concurrent_replay_and_invalid_batch_are_atomic(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    install_test_tokens(monkeypatch)
    payload = {"items": [knowledge()]}
    headers = bearer("concurrent-user")
    first, second = await asyncio.gather(
        client.post(
            "/api/v1/personal/items/import", headers=headers, json=payload
        ),
        client.post(
            "/api/v1/personal/items/import", headers=headers, json=payload
        ),
    )
    assert first.status_code == second.status_code == 201
    assert sum(first.json()["created"] + second.json()["created"]) == 1

    invalid = await client.post(
        "/api/v1/personal/items/import",
        headers=headers,
        json={
            "items": [
                knowledge("knowledge:valid"),
                {
                    "kind": "knowledge",
                    "source_key": "knowledge:invalid",
                    "title": "Bad item",
                    "data": {"title": "Missing stable item ID"},
                },
            ]
        },
    )
    assert invalid.status_code == 422
    async with session_factory() as session:
        count = await session.scalar(
            select(func.count()).select_from(PersonalWorkspaceItem)
        )
    assert count == 1
