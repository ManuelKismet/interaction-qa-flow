from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import select

from app.ai.embedding_provider import DeterministicFakeEmbeddingProvider
from app.core.config import Settings
from app.models.answer import AnswerStatus
from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.question import Question, QuestionStatus, QuestionVisibility
from app.models.team import Team
from app.models.user import User
from app.services.search import SearchService
from tests.test_answer_governance import headers, seed_governance
from tests.test_search_service import candidate


@pytest.mark.asyncio
async def test_admin_team_crud_and_tenant_validation(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        foreign_department = Department(
            organisation_id=ids["other_organisation"], name="Foreign Finance"
        )
        session.add(foreign_department)
        await session.commit()
        foreign_department_id = foreign_department.id

    forbidden = await client.post(
        "/api/v1/teams",
        headers=headers(ids, "employee"),
        json={"name": "Payroll", "department_id": str(ids["finance_department"])},
    )
    assert forbidden.status_code == 403

    payroll = await client.post(
        "/api/v1/teams",
        headers=headers(ids),
        json={
            "name": "Payroll",
            "description": "Monthly payroll operations",
            "department_id": str(ids["finance_department"]),
        },
    )
    assert payroll.status_code == 201
    assert payroll.json()["department"]["id"] == str(ids["finance_department"])
    updated = await client.patch(
        f"/api/v1/teams/{payroll.json()['id']}",
        headers=headers(ids),
        json={"description": "Payroll and deductions"},
    )
    assert updated.status_code == 200
    assert updated.json()["description"] == "Payroll and deductions"

    project = await client.post(
        "/api/v1/teams",
        headers=headers(ids),
        json={"name": "Project Alpha", "department_id": None},
    )
    assert project.status_code == 201
    assert project.json()["department"] is None

    cross_tenant = await client.patch(
        f"/api/v1/teams/{payroll.json()['id']}",
        headers=headers(ids),
        json={"department_id": str(foreign_department_id)},
    )
    assert cross_tenant.status_code == 404

    listed = await client.get("/api/v1/teams", headers=headers(ids, "employee"))
    assert listed.status_code == 200
    assert {item["name"] for item in listed.json()} >= {"Payroll", "Project Alpha"}
    async with session_factory() as session:
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.TEAM_UPDATED.value in actions


@pytest.mark.asyncio
async def test_user_can_join_multiple_teams_and_duplicates_are_blocked(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    team_ids = []
    for name in ("Payroll", "Project Alpha"):
        response = await client.post(
            "/api/v1/teams", headers=headers(ids), json={"name": name}
        )
        team_ids.append(response.json()["id"])

    for team_id in team_ids:
        added = await client.post(
            f"/api/v1/teams/{team_id}/members",
            headers=headers(ids),
            json={"user_id": str(ids["employee"])},
        )
        assert added.status_code == 201

    duplicate = await client.post(
        f"/api/v1/teams/{team_ids[0]}/members",
        headers=headers(ids),
        json={"user_id": str(ids["employee"])},
    )
    assert duplicate.status_code == 409
    foreign = await client.post(
        f"/api/v1/teams/{team_ids[0]}/members",
        headers=headers(ids),
        json={"user_id": str(ids["outsider"])},
    )
    assert foreign.status_code == 404

    members = await client.get(
        f"/api/v1/teams/{team_ids[0]}/members", headers=headers(ids)
    )
    assert [item["user"]["id"] for item in members.json()] == [str(ids["employee"])]
    removed = await client.delete(
        f"/api/v1/teams/{team_ids[0]}/members/{ids['employee']}",
        headers=headers(ids),
    )
    assert removed.status_code == 204

    async with session_factory() as session:
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.TEAM_CREATED.value in actions
        assert AuditAction.TEAM_MEMBER_ADDED.value in actions
        assert AuditAction.TEAM_MEMBER_REMOVED.value in actions


@pytest.mark.asyncio
async def test_question_team_consistency_and_department_governance(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        people = Department(organisation_id=ids["organisation"], name="People")
        session.add(people)
        await session.commit()
        people_id = people.id
    payroll = await client.post(
        "/api/v1/teams",
        headers=headers(ids),
        json={"name": "Payroll", "department_id": str(ids["finance_department"])},
    )
    payroll_id = payroll.json()["id"]
    project = await client.post(
        "/api/v1/teams", headers=headers(ids), json={"name": "Project Alpha"}
    )
    project_id = project.json()["id"]

    mismatched = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "title": "Payroll mismatch",
            "department_id": str(people_id),
            "team_id": payroll_id,
        },
    )
    assert mismatched.status_code == 409

    valid = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "title": "Payroll cutoff",
            "team_id": payroll_id,
        },
    )
    assert valid.status_code == 201
    assert valid.json()["department_id"] is None
    assert valid.json()["team_id"] == payroll_id
    answer = await client.post(
        f"/api/v1/questions/{valid.json()['id']}/answers",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "body": "Submit before Friday.",
        },
    )
    owner_verify = await client.post(
        f"/api/v1/answers/{answer.json()['id']}/verify",
        headers=headers(ids, "finance_owner"),
        json={},
    )
    assert owner_verify.status_code == 200

    cross_functional = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "title": "Project Alpha update",
            "team_id": project_id,
        },
    )
    cross_answer = await client.post(
        f"/api/v1/questions/{cross_functional.json()['id']}/answers",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "body": "Read the project board.",
        },
    )
    denied = await client.post(
        f"/api/v1/answers/{cross_answer.json()['id']}/verify",
        headers=headers(ids, "finance_owner"),
        json={},
    )
    assert denied.status_code == 403
    admin = await client.post(
        f"/api/v1/answers/{cross_answer.json()['id']}/verify",
        headers=headers(ids),
        json={},
    )
    assert admin.status_code == 200


@pytest.mark.asyncio
async def test_canonical_merge_preserves_team_and_search_returns_team(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    team_response = await client.post(
        "/api/v1/teams",
        headers=headers(ids),
        json={"name": "Payroll", "department_id": str(ids["finance_department"])},
    )
    team_id = team_response.json()["id"]
    duplicate = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(ids["organisation"]),
            "author_id": str(ids["employee"]),
            "title": "Payroll duplicate",
            "team_id": team_id,
        },
    )
    merged = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids),
        json={
            "duplicate_question_ids": [duplicate.json()["id"]],
            "reason": "Same finance guidance",
        },
    )
    assert merged.status_code == 200
    detail = await client.get(
        f"/api/v1/questions/{duplicate.json()['id']}",
        params={"organisation_id": str(ids["organisation"])},
    )
    assert detail.json()["team"]["id"] == team_id

    now = datetime(2026, 2, 1, tzinfo=UTC)
    actor = User(
        id=ids["employee"],
        organisation_id=ids["organisation"],
        email="employee@governance.test",
        display_name="Employee",
    )
    canonical, _, answer, department, _, similarity, challenge_count = candidate(
        actor,
        similarity=0.9,
        answer_status=AnswerStatus.VERIFIED,
        resolved_at=now,
        review_due_at=now + timedelta(days=30),
    )
    team = Team(
        id=team_id,
        organisation_id=ids["organisation"],
        department_id=ids["finance_department"],
        name="Payroll",
    )
    service = SearchService(
        AsyncMock(),
        DeterministicFakeEmbeddingProvider(),
        Settings(),
        clock=lambda: now,
    )
    service.permissions.actor = AsyncMock(return_value=actor)
    service.search_repository.semantic_candidates = AsyncMock(
        return_value=[
            (
                canonical,
                canonical,
                answer,
                department,
                team,
                similarity,
                challenge_count,
            )
        ]
    )
    results = await service.search(
        query="Payroll",
        limit=5,
        organisation_id=ids["organisation"],
        user_id=ids["employee"],
    )
    assert results[0].team.name == "Payroll"