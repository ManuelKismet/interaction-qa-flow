from datetime import datetime, timezone

import pytest
from sqlalchemy import select

from app.models.department import Department
from app.models.guided import GuidedSession, GuidedSessionVisibility
from app.models.question import Question, QuestionVisibility
from app.models.user import User
from tests.test_answer_governance import headers, seed_governance


@pytest.mark.asyncio
async def test_private_question_and_child_resources_require_visibility(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        visible_question = await session.scalar(
            select(Question).where(
                Question.organisation_id == ids["organisation"],
                Question.title == "How do I update my address?",
            )
        )
        visible_question_id = visible_question.id
    answer = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/answers",
        headers=headers(ids, "people_owner"),
        json={"body": "Synthetic answer"},
    )
    assert answer.status_code == 201, answer.text
    comment = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/comments",
        headers=headers(ids, "people_owner"),
        json={"body": "Synthetic comment"},
    )
    assert comment.status_code == 201, comment.text
    challenge = await client.post(
        f"/api/v1/answers/{answer.json()['id']}/challenges",
        headers=headers(ids, "employee"),
        json={"type": "incorrect", "reason": "Synthetic challenge"},
    )
    assert challenge.status_code == 201, challenge.text

    async with session_factory() as session:
        question = await session.get(Question, ids["finance_question"])
        question.visibility = QuestionVisibility.PRIVATE
        question.created_at = datetime(2099, 1, 1, tzinfo=timezone.utc)
        visible_question = await session.get(Question, visible_question_id)
        visible_question.created_at = datetime(2000, 1, 1, tzinfo=timezone.utc)
        await session.commit()

    hidden_question = str(ids["finance_question"])
    outsider = headers(ids, "people_owner")
    assert (
        await client.get(f"/api/v1/questions/{hidden_question}", headers=outsider)
    ).status_code == 403
    listed = await client.get(
        "/api/v1/questions?offset=0&limit=1", headers=outsider
    )
    assert listed.status_code == 200, listed.text
    assert [item["id"] for item in listed.json()] == [str(visible_question_id)]
    assert (
        await client.get(
            f"/api/v1/questions/{hidden_question}/answers", headers=outsider
        )
    ).status_code == 403
    assert (
        await client.post(
            f"/api/v1/questions/{hidden_question}/answers",
            headers=outsider,
            json={"body": "Must not be added"},
        )
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/questions/{hidden_question}/comments", headers=outsider
        )
    ).status_code == 403
    assert (
        await client.post(
            f"/api/v1/questions/{hidden_question}/comments",
            headers=outsider,
            json={"body": "Must not be added"},
        )
    ).status_code == 403
    assert (
        await client.patch(
            f"/api/v1/answers/{answer.json()['id']}",
            headers=outsider,
            json={"body": "Must not be changed"},
        )
    ).status_code == 403
    assert (
        await client.delete(
            f"/api/v1/answers/{answer.json()['id']}", headers=outsider
        )
    ).status_code == 403
    assert (
        await client.post(
            f"/api/v1/answers/{answer.json()['id']}/reaction",
            headers=outsider,
            json={"reaction": "helpful"},
        )
    ).status_code == 403
    for suffix in ("challenges", "versions"):
        assert (
            await client.get(
                f"/api/v1/answers/{answer.json()['id']}/{suffix}",
                headers=outsider,
            )
        ).status_code == 403
    assert (
        await client.post(
            f"/api/v1/challenges/{challenge.json()['id']}/reject",
            headers=headers(ids, "admin"),
            json={},
        )
    ).status_code == 403
    review_queue = await client.get(
        "/api/v1/review-queue", headers=headers(ids, "admin")
    )
    if review_queue.status_code == 200:
        assert all(
            item["question_id"] != hidden_question for item in review_queue.json()
        )

    comment_id = comment.json()["id"]
    assert (
        await client.patch(
            f"/api/v1/comments/{comment_id}",
            headers=outsider,
            json={"body": "Must not be changed"},
        )
    ).status_code == 403
    assert (
        await client.delete(f"/api/v1/comments/{comment_id}", headers=outsider)
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/questions/{hidden_question}/duplicate-candidates",
            headers=outsider,
        )
    ).status_code == 403

    author = headers(ids, "employee")
    assert (
        await client.get(f"/api/v1/questions/{hidden_question}", headers=author)
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/questions/{hidden_question}/answers", headers=author
        )
    ).status_code == 200


@pytest.mark.asyncio
async def test_canonical_metadata_only_includes_visible_questions(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        root = await session.get(Question, ids["finance_question"])
        private_alias = Question(
            organisation_id=ids["organisation"],
            department_id=ids["finance_department"],
            author_id=ids["employee"],
            title="Private historical alias",
            visibility=QuestionVisibility.PRIVATE,
            canonical_question_id=root.id,
        )
        session.add(private_alias)
        await session.flush()
        public_alias = Question(
            organisation_id=ids["organisation"],
            department_id=ids["finance_department"],
            author_id=ids["employee"],
            title="Visible alias of private root",
            visibility=QuestionVisibility.ORGANISATION,
            canonical_question_id=root.id,
        )
        public_root = Question(
            organisation_id=ids["organisation"],
            department_id=ids["finance_department"],
            author_id=ids["employee"],
            title="Visible canonical question",
        )
        session.add(public_root)
        await session.flush()
        hidden_aliases = [
            Question(
                organisation_id=ids["organisation"],
                department_id=ids["finance_department"],
                author_id=ids["employee"],
                title=f"Private alias {index}",
                visibility=QuestionVisibility.PRIVATE,
                canonical_question_id=public_root.id,
                updated_at=datetime(2099, 1, index + 1, tzinfo=timezone.utc),
            )
            for index in range(6)
        ]
        visible_alias = Question(
            organisation_id=ids["organisation"],
            department_id=ids["finance_department"],
            author_id=ids["employee"],
            title="Visible historical alias",
            canonical_question_id=public_root.id,
            updated_at=datetime(2000, 1, 1, tzinfo=timezone.utc),
        )
        session.add_all([*hidden_aliases, visible_alias])
        root.visibility = QuestionVisibility.PRIVATE
        session.add(public_alias)
        await session.commit()
        private_alias_id = private_alias.id
        public_alias_id = public_alias.id
        public_root_id = public_root.id
        visible_alias_id = visible_alias.id

    response = await client.get(
        f"/api/v1/questions/{public_alias_id}",
        headers=headers(ids, "people_owner"),
    )
    assert response.status_code == 200, response.text
    assert response.json()["canonical_question"] is None

    root = await client.get(
        f"/api/v1/questions/{ids['finance_question']}",
        headers=headers(ids, "employee"),
    )
    assert root.status_code == 200, root.text
    assert str(private_alias_id) in [item["id"] for item in root.json()["aliases"]]

    root_for_other_user = await client.get(
        f"/api/v1/questions/{ids['finance_question']}",
        headers=headers(ids, "people_owner"),
    )
    assert root_for_other_user.status_code == 403
    visible_root = await client.get(
        f"/api/v1/questions/{public_root_id}",
        headers=headers(ids, "people_owner"),
    )
    assert visible_root.status_code == 200, visible_root.text
    assert [item["id"] for item in visible_root.json()["aliases"]] == [
        str(visible_alias_id)
    ]


@pytest.mark.asyncio
async def test_department_question_access_requires_matching_non_null_department(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        question = await session.get(Question, ids["finance_question"])
        question.visibility = QuestionVisibility.DEPARTMENT
        await session.commit()

    path = f"/api/v1/questions/{ids['finance_question']}"
    assert (await client.get(path, headers=headers(ids, "finance_owner"))).status_code == 200
    assert (await client.get(path, headers=headers(ids, "people_owner"))).status_code == 403
    assert (await client.get(path, headers=headers(ids, "admin"))).status_code == 403

    async with session_factory() as session:
        question = await session.get(Question, ids["finance_question"])
        question.department_id = None
        await session.commit()
    assert (await client.get(path, headers=headers(ids, "admin"))).status_code == 403


@pytest.mark.asyncio
async def test_department_session_requires_valid_department_and_protects_reads(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    missing = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={"title": "Missing department", "visibility": "department"},
    )
    assert missing.status_code == 409, missing.text

    async with session_factory() as session:
        foreign_department = Department(
            organisation_id=ids["other_organisation"], name="Foreign"
        )
        session.add(foreign_department)
        await session.commit()
        foreign_department_id = foreign_department.id

    foreign = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={
            "title": "Foreign department",
            "department_id": str(foreign_department_id),
            "visibility": "department",
        },
    )
    assert foreign.status_code == 404, foreign.text

    created = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={
            "title": "Finance session",
            "department_id": str(ids["finance_department"]),
            "visibility": "department",
        },
    )
    assert created.status_code == 201, created.text
    session_id = created.json()["id"]
    detail_path = f"/api/v1/guided/sessions/{session_id}"
    assert (
        await client.get(detail_path, headers=headers(ids, "finance_owner"))
    ).status_code == 200
    assert (
        await client.get(detail_path, headers=headers(ids, "people_owner"))
    ).status_code == 403
    assert (
        await client.get(
            f"{detail_path}/revisions", headers=headers(ids, "people_owner")
        )
    ).status_code == 403
    for output in ("json", "csv"):
        assert (
            await client.get(
                f"{detail_path}/export/{output}",
                headers=headers(ids, "people_owner"),
            )
        ).status_code == 403
    listed = await client.get(
        "/api/v1/guided/sessions", headers=headers(ids, "people_owner")
    )
    assert all(item["id"] != session_id for item in listed.json())

    removed_department = await client.patch(
        detail_path,
        headers=headers(ids, "employee"),
        json={"department_id": None},
    )
    assert removed_department.status_code == 409, removed_department.text

    private = await client.post(
        "/api/v1/guided/sessions",
        headers=headers(ids, "employee"),
        json={"title": "Private session"},
    )
    assert private.status_code == 201, private.text
    missing_on_update = await client.patch(
        f"/api/v1/guided/sessions/{private.json()['id']}",
        headers=headers(ids, "employee"),
        json={"visibility": "department"},
    )
    assert missing_on_update.status_code == 409, missing_on_update.text
    imported = await client.post(
        "/api/v1/guided/import/legacy",
        headers=headers(ids, "employee"),
        json={
            "payload": {
                "meta": {
                    "caseTitle": "Legacy import",
                    "visibility": "department",
                },
                "participants": [{"id": "p1", "name": "Participant"}],
                "flow": [],
            }
        },
    )
    assert imported.status_code == 200, imported.text
    assert imported.json()["session"]["visibility"] == "private"
    assert imported.json()["session"]["department_id"] is None


@pytest.mark.asyncio
async def test_departmentless_legacy_session_is_not_shared_by_null_match(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        departmentless = User(
            organisation_id=ids["organisation"],
            email="departmentless@governance.test",
            display_name="Departmentless",
        )
        legacy = GuidedSession(
            organisation_id=ids["organisation"],
            created_by=ids["employee"],
            title="Legacy departmentless session",
            visibility=GuidedSessionVisibility.DEPARTMENT,
            department_id=None,
        )
        session.add_all([departmentless, legacy])
        await session.commit()
        user_id, session_id = departmentless.id, legacy.id

    def read_headers(user_id):
        return {
            "X-Organisation-ID": str(ids["organisation"]),
            "X-User-ID": str(user_id),
        }

    path = f"/api/v1/guided/sessions/{session_id}"
    assert (await client.get(path, headers=read_headers(user_id))).status_code == 403
    assert (
        await client.get(path, headers=read_headers(ids["people_owner"]))
    ).status_code == 403
    assert (
        await client.get(path, headers=read_headers(ids["employee"]))
    ).status_code == 200
    listing = await client.get(
        "/api/v1/guided/sessions", headers=read_headers(user_id)
    )
    assert all(item["id"] != str(session_id) for item in listing.json())
