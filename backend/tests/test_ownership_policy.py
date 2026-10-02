from uuid import UUID

import pytest
from sqlalchemy import select

from app.models.answer import Answer, AnswerStatus
from app.models.answer_version import AnswerVersion
from app.models.department import Department
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.organisation import Organisation
from app.models.question import Question
from app.models.user import User, UserRole


def headers(organisation_id, user_id):
    return {
        "X-Organisation-ID": str(organisation_id),
        "X-User-ID": str(user_id),
    }


async def seed_policy_users(session_factory):
    async with session_factory() as session:
        organisation = Organisation(name="Policy Organisation", slug="policy-org")
        session.add(organisation)
        await session.flush()
        department = Department(
            organisation_id=organisation.id,
            name="Policy Department",
        )
        session.add(department)
        await session.flush()
        users = {
            "author": User(
                organisation_id=organisation.id,
                email="policy-author@example.test",
                display_name="Author",
            ),
            "contributor": User(
                organisation_id=organisation.id,
                email="policy-contributor@example.test",
                display_name="Contributor",
            ),
            "unrelated": User(
                organisation_id=organisation.id,
                email="policy-unrelated@example.test",
                display_name="Unrelated",
            ),
            "department_owner": User(
                organisation_id=organisation.id,
                department_id=department.id,
                email="policy-owner@example.test",
                display_name="Department Owner",
                role=UserRole.ANSWER_OWNER,
            ),
            "admin": User(
                organisation_id=organisation.id,
                email="policy-admin@example.test",
                display_name="Administrator",
                role=UserRole.ADMIN,
            ),
            "private_author": User(
                organisation_id=organisation.id,
                email="policy-private@example.test",
                display_name="Private Author",
            ),
        }
        session.add_all(users.values())
        await session.flush()
        session.add(
            DepartmentAnswerOwner(
                organisation_id=organisation.id,
                department_id=department.id,
                user_id=users["department_owner"].id,
            )
        )
        await session.commit()
        return {
            "organisation": organisation.id,
            "department": department.id,
            **{key: user.id for key, user in users.items()},
        }


async def create_question(client, ids, user_key="author", **values):
    response = await client.post(
        "/api/v1/questions",
        headers=headers(ids["organisation"], ids[user_key]),
        json={
            "title": values.get("title", "How does the policy work?"),
            "body": values.get("body"),
            "department_id": (
                str(values["department_id"])
                if values.get("department_id")
                else None
            ),
            "visibility": values.get("visibility", "organisation"),
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def create_answer(client, ids, question, user_key="contributor"):
    response = await client.post(
        f"/api/v1/questions/{question['id']}/answers",
        headers=headers(ids["organisation"], ids[user_key]),
        json={"body": "A useful answer."},
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_unanswered_author_can_edit_archive_and_restore(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_policy_users(session_factory)
    question = await create_question(client, ids)
    path = f"/api/v1/questions/{question['id']}"

    denied = await client.patch(
        path,
        headers=headers(ids["organisation"], ids["unrelated"]),
        json={"title": "Unauthorized edit"},
    )
    assert denied.status_code == 403

    updated = await client.patch(
        path,
        headers=headers(ids["organisation"], ids["author"]),
        json={"title": "Updated unanswered question"},
    )
    assert updated.status_code == 200

    archived = await client.post(
        f"{path}/archive",
        headers=headers(ids["organisation"], ids["author"]),
        json={"reason": "The question is no longer relevant."},
    )
    assert archived.status_code == 200
    assert archived.json()["archived_by"] == str(ids["author"])
    assert archived.json()["archive_reason"] == "The question is no longer relevant."

    restored = await client.post(
        f"{path}/restore",
        headers=headers(ids["organisation"], ids["author"]),
        json={"reason": "The question is relevant again."},
    )
    assert restored.status_code == 200
    assert restored.json()["status"] == "open"
    assert restored.json()["archived_at"] is None
    versions = await client.get(
        f"{path}/versions",
        headers=headers(ids["organisation"], ids["author"]),
    )
    assert versions.status_code == 200
    assert [item["change_reason"] for item in versions.json()] == [
        "The question is relevant again.",
        "The question is no longer relevant.",
    ]


@pytest.mark.asyncio
async def test_answered_question_author_requests_admin_review(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_policy_users(session_factory)
    question = await create_question(client, ids)
    await create_answer(client, ids, question)
    path = f"/api/v1/questions/{question['id']}"

    for method, suffix, json_body in [
        ("patch", "", {"title": "Silent rewrite"}),
        ("post", "/archive", {"reason": "Remove it"}),
    ]:
        response = await getattr(client, method)(
            f"{path}{suffix}",
            headers=headers(ids["organisation"], ids["author"]),
            json=json_body,
        )
        assert response.status_code == 403

    request = await client.post(
        f"{path}/change-requests",
        headers=headers(ids["organisation"], ids["author"]),
        json={
            "title": "Reviewed question wording",
            "reason": "Clarify the current process.",
        },
    )
    assert request.status_code == 201, request.text
    assert request.json()["status"] == "pending"
    assert request.json()["change_title"] is True

    admin_headers = headers(ids["organisation"], ids["admin"])
    queue = await client.get("/api/v1/questions/change-requests", headers=admin_headers)
    assert queue.status_code == 200
    assert [item["id"] for item in queue.json()] == [request.json()["id"]]
    denied_queue = await client.get(
        "/api/v1/questions/change-requests",
        headers=headers(ids["organisation"], ids["department_owner"]),
    )
    assert denied_queue.status_code == 403

    reviewed = await client.post(
        f"/api/v1/questions/change-requests/{request.json()['id']}/review",
        headers=admin_headers,
        json={"decision": "approve", "review_note": "Approved after review."},
    )
    assert reviewed.status_code == 200, reviewed.text
    assert reviewed.json()["status"] == "approved"
    detail = await client.get(path, headers=admin_headers)
    assert detail.json()["title"] == "Reviewed question wording"
    versions = await client.get(f"{path}/versions", headers=admin_headers)
    assert versions.json()[0]["title"] == "How does the policy work?"
    assert versions.json()[0]["change_reason"] == "Approved after review."


@pytest.mark.asyncio
async def test_accepted_question_changes_are_admin_only_and_invalidate_approval(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_policy_users(session_factory)
    question = await create_question(
        client,
        ids,
        department_id=ids["department"],
    )
    answer = await create_answer(client, ids, question)
    path = f"/api/v1/questions/{question['id']}"
    resolved = await client.post(
        f"{path}/resolve",
        headers=headers(ids["organisation"], ids["author"]),
        json={"answer_id": answer["id"]},
    )
    assert resolved.status_code == 200

    for user_key in ("author", "department_owner"):
        update = await client.patch(
            path,
            headers=headers(ids["organisation"], ids[user_key]),
            json={"title": "Unapproved rewrite"},
        )
        assert update.status_code == 403
        reopen = await client.post(
            f"{path}/reopen",
            headers=headers(ids["organisation"], ids[user_key]),
            json={},
        )
        assert reopen.status_code == 403

    admin_headers = headers(ids["organisation"], ids["admin"])
    changed = await client.patch(
        path,
        headers=admin_headers,
        json={"title": "Reviewed approved wording", "reason": "Policy changed."},
    )
    assert changed.status_code == 200, changed.text
    assert changed.json()["status"] == "under_review"
    assert changed.json()["accepted_answer_id"] is None

    detail = await client.get(path, headers=admin_headers)
    assert detail.json()["answers"][0]["status"] == "community"
    versions = await client.get(f"{path}/versions", headers=admin_headers)
    assert versions.json()[0]["status_snapshot"] == "resolved"
    async with session_factory() as session:
        answer_versions = list(
            await session.scalars(
                select(AnswerVersion).where(
                    AnswerVersion.question_id == UUID(question["id"])
                )
            )
        )
        stored_question = await session.get(Question, UUID(question["id"]))
        assert len(answer_versions) == 1
        assert answer_versions[0].status_snapshot == AnswerStatus.COMMUNITY
        assert stored_question.protected_at is not None

    accepted_again = await client.post(
        f"{path}/resolve",
        headers=admin_headers,
        json={"answer_id": answer["id"]},
    )
    assert accepted_again.status_code == 200
    author_reopen = await client.post(
        f"{path}/reopen",
        headers=headers(ids["organisation"], ids["author"]),
        json={},
    )
    assert author_reopen.status_code == 403

    archived = await client.post(
        f"{path}/archive",
        headers=admin_headers,
        json={"reason": "Approved content retired."},
    )
    assert archived.status_code == 200
    author_restore = await client.post(
        f"{path}/restore",
        headers=headers(ids["organisation"], ids["author"]),
        json={"reason": "Try to restore approved content."},
    )
    assert author_restore.status_code == 403
    restored = await client.post(
        f"{path}/restore",
        headers=admin_headers,
        json={"reason": "Administrator restored after review."},
    )
    assert restored.status_code == 200
    assert restored.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_verified_answers_are_admin_managed_and_archived_recoverably(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_policy_users(session_factory)
    question = await create_question(
        client,
        ids,
        department_id=ids["department"],
    )
    answer = await create_answer(client, ids, question)
    answer_path = f"/api/v1/answers/{answer['id']}"
    owner_headers = headers(ids["organisation"], ids["department_owner"])
    verified = await client.post(
        f"{answer_path}/verify",
        headers=owner_headers,
        json={},
    )
    assert verified.status_code == 200, verified.text

    answer_author_update = await client.patch(
        answer_path,
        headers=headers(ids["organisation"], ids["contributor"]),
        json={"body": "Silent verified rewrite."},
    )
    assert answer_author_update.status_code == 403
    owner_update = await client.patch(
        answer_path,
        headers=owner_headers,
        json={"body": "Department owner cannot edit.", "reason": "Not permitted."},
    )
    assert owner_update.status_code == 403

    admin_headers = headers(ids["organisation"], ids["admin"])
    admin_update = await client.patch(
        answer_path,
        headers=admin_headers,
        json={"body": "Reviewed replacement answer.", "reason": "New guidance."},
    )
    assert admin_update.status_code == 200, admin_update.text
    assert admin_update.json()["status"] == "community"
    question_detail = await client.get(
        f"/api/v1/questions/{question['id']}",
        headers=admin_headers,
    )
    assert question_detail.json()["status"] == "under_review"
    histories = await client.get(f"{answer_path}/versions", headers=admin_headers)
    assert histories.status_code == 200
    assert histories.json()[0]["body"] == "A useful answer."
    assert histories.json()[0]["status_snapshot"] == "verified"

    protected_answer_delete = await client.delete(
        answer_path,
        headers=headers(ids["organisation"], ids["contributor"]),
    )
    assert protected_answer_delete.status_code == 403
    admin_delete = await client.delete(
        answer_path,
        headers=admin_headers,
        params={"reason": "Outdated content removed."},
    )
    assert admin_delete.status_code == 204
    hidden = await client.get(
        f"/api/v1/questions/{question['id']}/answers",
        headers=admin_headers,
    )
    assert hidden.json() == []

    restored = await client.post(
        f"{answer_path}/restore",
        headers=admin_headers,
        json={"reason": "Restore for re-review."},
    )
    assert restored.status_code == 200, restored.text
    assert restored.json()["status"] == "community"
    assert restored.json()["body"] == "Reviewed replacement answer."
    async with session_factory() as session:
        stored_answer = await session.get(Answer, UUID(answer["id"]))
        assert stored_answer.archived_at is None


@pytest.mark.asyncio
async def test_private_content_visibility_is_not_bypassed_by_admin(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_policy_users(session_factory)
    question = await create_question(
        client,
        ids,
        user_key="private_author",
        title="Private knowledge",
        visibility="private",
    )
    private_path = f"/api/v1/questions/{question['id']}"
    admin_headers = headers(ids["organisation"], ids["admin"])
    assert (await client.get(private_path, headers=admin_headers)).status_code == 403
    admin_edit = await client.patch(
        private_path,
        headers=admin_headers,
        json={"title": "Administrator private edit", "reason": "Policy."},
    )
    assert admin_edit.status_code == 403
