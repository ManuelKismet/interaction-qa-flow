import copy
from datetime import UTC, datetime
from uuid import UUID

import pytest
from app.models.audit_event import AuditEvent
from app.models.guided import (
    GuidedAnswer,
    GuidedParticipant,
    GuidedQuestion,
    GuidedSession,
    GuidedSessionRevision,
)
from app.models.organisation_owner import OrganisationOwner
from app.models.organisation_permission import OrganisationPermissionGrant
from app.models.user import User, UserRole
from sqlalchemy import func, select

from tests.test_answer_governance import headers, seed_governance
from tests.test_guided import add_participant, add_question, answer, create_session


def legacy_payload():
    return {
        "meta": {"caseTitle": "  Case\n title  ", "interviewer": " Owner ", "interviewee": " Context\n "},
        "participants": [
            {"id": "alice", "name": " Alice ", "role": " Investigator ", "notes": " Notes\n ", "sort_order": 3},
            {"id": "bob", "name": "Bob"},
        ],
        "flow": [
            {
                "id": "root", "question": " What\n happened? ", "scope": "shared",
                "answers": {
                    "alice": {
                        "answer": " Email\n ", "branchesCollapsed": True,
                        "branches": [{
                            "id": "child", "question": " Who? ", "scope": "participant", "participantId": "alice",
                            "answers": {"alice": {"answer": "", "branches": [{
                                "id": "grandchild", "question": " Details? ", "scope": "participant",
                                "participantId": "alice", "answers": {"alice": {"answer": "  "}},
                            }]}},
                        }],
                    },
                    "bob": {"answer": "Phone", "branches": [{
                        "question": " Caller? ", "scope": "participant", "participantId": "bob",
                        "answers": {"bob": {"answer": "Team"}},
                    }]},
                },
            },
            {"question": " Only Bob? ", "scope": "participant", "participantId": "bob", "answers": {}},
        ],
    }


async def row_counts(factory):
    async with factory() as session:
        return tuple(
            [await session.scalar(select(func.count()).select_from(model))
             for model in (GuidedSession, GuidedParticipant, GuidedQuestion, GuidedAnswer, GuidedSessionRevision, AuditEvent)]
        )


def semantic_session(detail):
    participants = {item["id"]: item["name"] for item in detail["participants"]}

    def node(item):
        answers = {answer["id"]: participants[answer["participant_id"]] for answer in item["answers"]}
        return {
            "text": item["text"], "scope": item["scope"],
            "target": participants.get(item["target_participant_id"]),
            "source": item["source"], "main_order": item["main_order_index"],
            "branch_order": item["branch_order_index"], "deleted_at": item["deleted_at"],
            "answers": sorted((participants[answer["participant_id"]], answer["body"], answer["branches_collapsed"])
                              for answer in item["answers"]),
            "branches": sorted([(answers[child["triggering_answer_id"]], node(child))
                                for child in item["follow_ups"]], key=lambda item: (item[0], item[1]["branch_order"])),
        }

    return {
        "title": detail["title"], "owner": detail["owner_text"], "context": detail["context_reference"],
        "participants": [(item["name"], item["role_label"], item["notes"], item["sort_order"])
                         for item in detail["participants"]],
        "questions": [node(item) for item in detail["questions"]],
    }


@pytest.mark.asyncio
async def test_lossless_legacy_and_guided_roundtrip_including_deleted_branches(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    original = legacy_payload()
    result = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": original})
    assert result.status_code == 200, result.text
    first = result.json()["session"]
    assert result.json()["warnings"] == []
    assert first["title"] == original["meta"]["caseTitle"]
    assert first["participants"][1]["role_label"] == " Investigator "
    child = first["questions"][0]["follow_ups"][0]
    deleted = await client.delete(f"/api/v1/guided/questions/{child['id']}", headers=headers(ids, "employee"))
    assert deleted.status_code == 200
    exported = await client.get(f"/api/v1/guided/sessions/{first['id']}/export/json", headers=headers(ids, "employee"))
    assert exported.status_code == 200
    envelope = exported.json()
    assert any(item["deleted_at"] for item in envelope["session"]["questions"][0]["follow_ups"])
    snapshot = copy.deepcopy(envelope)
    imported = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": envelope})
    assert imported.status_code == 200, imported.text
    second = imported.json()["session"]
    reexport = await client.get(f"/api/v1/guided/sessions/{second['id']}/export/json", headers=headers(ids, "employee"))
    assert semantic_session(reexport.json()["session"]) == semantic_session(envelope["session"])
    assert second["id"] != first["id"]
    assert second["visibility"] == "private" and second["status"] == "draft"
    assert envelope == snapshot
    assert await row_counts(factory) == (2, 4, 10, 10, 1, 3)


@pytest.mark.asyncio
@pytest.mark.parametrize("bad", [
    {}, {"session": {}}, {"kind": "intqaflow-guided-session", "version": 2, "session": {}},
    {"workspaces": []}, {"sessions": []}, {"flow": "wrong"},
    {"flow": [None]}, {"flow": [{"question": " \n "}]},
    {"flow": [{"question": "valid"}, {"question": 123}]},
    {"participants": [{"id": "a"}, {"id": "a"}], "flow": []},
    {"participants": "bad", "flow": []},
    {"participants": [{"id": "a"}], "flow": [{"question": "Q", "scope": "participant", "participantId": "missing"}]},
    {"participants": [{"id": "a"}], "flow": [{"question": "Q", "answers": {"missing": {"answer": "A"}}}]},
    {"flow": [{"question": "Q", "branchesCollapsed": "false"}]},
    {"flow": [{"question": "Q", "branches": {}}]},
    {"flow": [{"question": "Q", "answer": None}]},
    {"flow": [{"question": "Q", "scope": []}]},
    {"flow": [{"question": "Q", "scope": "participant", "participantId": {}}]},
    {"meta": {"caseTitle": "x" * 501}, "flow": []},
])
async def test_invalid_imports_have_explicit_diagnostics_and_zero_mutations(app_client, bad):
    client, factory = app_client
    ids = await seed_governance(factory)
    before = await row_counts(factory)
    response = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": bad})
    assert response.status_code == 409, response.text
    assert response.json()["detail"]
    assert await row_counts(factory) == before


@pytest.mark.asyncio
async def test_guided_graph_rejects_bad_references_and_types_before_mutation(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    first = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": legacy_payload()})
    export = await client.get(f"/api/v1/guided/sessions/{first.json()['session']['id']}/export/json", headers=headers(ids, "employee"))
    original = export.json()
    before = await row_counts(factory)
    for case in ("target", "trigger", "duplicate", "answer_question", "collapsed", "late_blank", "foreign"):
        bad = copy.deepcopy(original)
        root = bad["session"]["questions"][0]
        if case == "target":
            root["target_participant_id"] = bad["session"]["participants"][0]["id"]
        elif case == "trigger":
            root["follow_ups"][0]["triggering_answer_id"] = root["id"]
        elif case == "duplicate":
            bad["session"]["questions"].append(copy.deepcopy(root))
        elif case == "answer_question":
            root["answers"][0]["question_id"] = root["follow_ups"][0]["id"]
        elif case == "collapsed":
            root["answers"][0]["branches_collapsed"] = "false"
        elif case == "late_blank":
            root["follow_ups"][-1]["text"] = " \n "
        else:
            root["answers"][0]["organisation_id"] = str(ids["other_organisation"])
        response = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": bad})
        assert response.status_code == 409, (case, response.text)
        assert await row_counts(factory) == before


@pytest.mark.asyncio
async def test_explicit_import_warnings_and_legacy_single_answer_compatibility(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    payload = {"meta": {"caseTitle": "Legacy", "unsupported": "retained in original"},
               "flow": [{"question": " Q ", "answer": " A ", "branches": [{"question": "Follow", "answer": ""}]}]}
    response = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": payload})
    assert response.status_code == 200, response.text
    assert "meta.unsupported" in response.json()["warnings"][0]
    assert any("Participant 1" in warning for warning in response.json()["warnings"])
    root = response.json()["session"]["questions"][0]
    assert root["answers"][0]["body"] == " A "
    assert root["follow_ups"][0]["answers"][0]["body"] == ""


@pytest.mark.asyncio
async def test_guided_import_explains_private_copy_policy_and_unsupported_fields(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    created = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": legacy_payload()})
    session_id = created.json()["session"]["id"]
    await client.patch(f"/api/v1/guided/sessions/{session_id}", headers=headers(ids, "employee"), json={"visibility": "organisation"})
    await client.post(f"/api/v1/guided/sessions/{session_id}/start", headers=headers(ids, "employee"))
    exported = await client.get(f"/api/v1/guided/sessions/{session_id}/export/json", headers=headers(ids, "employee"))
    payload = exported.json()
    payload["session"]["participants"][0]["customLabel"] = "Not silently ignored"
    payload["session"]["questions"][0]["answers"][0]["customAnswer"] = "Not silently ignored"
    response = await client.post("/api/v1/guided/import/legacy", headers=headers(ids, "employee"), json={"payload": payload})
    assert response.status_code == 200, response.text
    warnings = response.json()["warnings"]
    assert any("customLabel" in warning for warning in warnings)
    assert any("customAnswer" in warning for warning in warnings)
    assert any("new private draft" in warning for warning in warnings)
    assert response.json()["session"]["visibility"] == "private"
    assert response.json()["session"]["status"] == "draft"
    assert response.json()["session"]["started_at"] is None
    original = await client.get(f"/api/v1/guided/sessions/{session_id}", headers=headers(ids, "employee"))
    assert original.json()["visibility"] == "organisation" and original.json()["status"] == "active"


@pytest.mark.asyncio
async def test_blank_answer_persists_but_blank_questions_rejected_and_conflicts_do_not_mutate(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    guided = await create_session(client, ids)
    participant = await add_participant(client, ids, guided["id"], "Alice")
    question = await add_question(client, ids, guided["id"], " Question ")
    saved = await answer(client, ids, question["id"], participant["id"], "Original")
    revision = saved["session_revision"]
    cleared = await client.patch(f"/api/v1/guided/answers/{saved['id']}", headers=headers(ids, "employee"),
                                 json={"body": "", "expected_revision": revision})
    assert cleared.status_code == 200 and cleared.json()["body"] == ""
    assert cleared.json()["session_revision"] == revision + 1
    before = await row_counts(factory)
    for path, body in (
        (f"answers/{saved['id']}", {"body": "stale", "expected_revision": revision}),
        (f"questions/{question['id']}", {"text": "stale", "expected_revision": revision}),
    ):
        response = await client.patch(f"/api/v1/guided/{path}", headers=headers(ids, "employee"), json=body)
        assert response.status_code == 409
    stale = await client.post(f"/api/v1/guided/questions/{question['id']}/answers", headers=headers(ids, "employee"),
                             json={"participant_id": participant["id"], "body": "stale", "expected_revision": revision})
    assert stale.status_code == 409
    for text in ("", " \n "):
        response = await client.patch(f"/api/v1/guided/questions/{question['id']}", headers=headers(ids, "employee"), json={"text": text})
        assert response.status_code == 422
        response = await client.post(f"/api/v1/guided/sessions/{guided['id']}/questions", headers=headers(ids, "employee"),
                                    json={"text": text, "scope": "shared"})
        assert response.status_code == 422
        response = await client.post(f"/api/v1/guided/answers/{saved['id']}/follow-ups", headers=headers(ids, "employee"), json={"text": text})
        assert response.status_code == 422
    assert await row_counts(factory) == before
    loaded = await client.get(f"/api/v1/guided/sessions/{guided['id']}", headers=headers(ids, "employee"))
    assert loaded.json()["questions"][0]["text"] == " Question "
    assert loaded.json()["questions"][0]["answers"][0]["body"] == ""
    renamed = await client.patch(f"/api/v1/guided/questions/{question['id']}", headers=headers(ids, "employee"),
                                json={"text": "  Changed\n ", "expected_revision": loaded.json()["revision"]})
    assert renamed.status_code == 200
    assert renamed.json()["text"] == "  Changed\n "


@pytest.mark.asyncio
@pytest.mark.parametrize("authority,can_edit", [("owner", True), ("legacy", True), ("role_only", False), ("revoked", False), ("scoped", False)])
async def test_guided_real_authority_and_private_creator_matrix(app_client, authority, can_edit):
    client, factory = app_client
    ids = await seed_governance(factory)
    async with factory() as session:
        actor = await session.get(User, ids["finance_owner"])
        actor.role = UserRole.ADMIN if authority == "role_only" else UserRole.EMPLOYEE
        if authority == "owner":
            session.add(OrganisationOwner(organisation_id=ids["organisation"], user_id=actor.id, appointed_by=None))
        elif authority != "role_only":
            session.add(OrganisationPermissionGrant(
                organisation_id=ids["organisation"], user_id=actor.id,
                permission="manage_members" if authority == "scoped" else "legacy_admin",
                scope_type="department" if authority == "scoped" else "organisation",
                scope_id=ids["finance_department"] if authority == "scoped" else None,
                granted_by=ids["admin"],
                revoked_at=datetime.now(UTC) if authority == "revoked" else None,
            ))
        await session.commit()
    private = await create_session(client, ids)
    visible = await create_session(client, ids, title="Shared")
    await client.patch(f"/api/v1/guided/sessions/{visible['id']}", headers=headers(ids, "employee"), json={"visibility": "organisation"})
    template = await client.post("/api/v1/guided/templates", headers=headers(ids, "employee"),
                                 json={"name": "Owned template", "questions": [{"text": "Q"}]})
    actor_headers = headers(ids, "finance_owner")
    for path in (f"sessions/{visible['id']}", f"templates/{template.json()['id']}"):
        response = await client.patch(f"/api/v1/guided/{path}", headers=actor_headers,
                                      json={"title": "Allowed"} if path.startswith("sessions") else {"name": "Allowed"})
        assert response.status_code == (200 if can_edit else 403), (authority, response.text)
    private_read = await client.get(f"/api/v1/guided/sessions/{private['id']}", headers=actor_headers)
    private_edit = await client.patch(f"/api/v1/guided/sessions/{private['id']}", headers=actor_headers, json={"title": "Denied"})
    assert private_read.status_code == private_edit.status_code == 403
    creator_edit = await client.patch(f"/api/v1/guided/sessions/{private['id']}", headers=headers(ids, "employee"), json={"title": "Creator allowed"})
    assert creator_edit.status_code == 200
    async with factory() as session:
        assert (await session.get(GuidedSession, UUID(private["id"]))).title == "Creator allowed"


@pytest.mark.asyncio
async def test_revoking_live_guided_grant_immediately_denies_writes(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    guided = await create_session(client, ids)
    participant = await add_participant(client, ids, guided["id"], "Alice")
    question = await add_question(client, ids, guided["id"], "Question")
    await client.patch(f"/api/v1/guided/sessions/{guided['id']}", headers=headers(ids, "employee"), json={"visibility": "organisation"})
    saved = await client.post(f"/api/v1/guided/questions/{question['id']}/answers", headers=headers(ids, "admin"),
                              json={"participant_id": participant["id"], "body": "Allowed"})
    assert saved.status_code == 200
    async with factory() as session:
        grant = await session.scalar(select(OrganisationPermissionGrant).where(
            OrganisationPermissionGrant.user_id == ids["admin"],
            OrganisationPermissionGrant.permission == "legacy_admin",
        ))
        grant.revoked_at = datetime.now(UTC)
        await session.commit()
    before = await row_counts(factory)
    response = await client.patch(f"/api/v1/guided/answers/{saved.json()['id']}", headers=headers(ids, "admin"), json={"body": "Denied"})
    assert response.status_code == 403
    assert await row_counts(factory) == before
    async with factory() as session:
        assert (await session.get(GuidedAnswer, UUID(saved.json()["id"]))).body == "Allowed"
