from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import func, select

from app.models.answer import Answer, AnswerStatus
from app.models.answer_challenge import AnswerChallenge, ChallengeStatus
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.organisation import Organisation
from app.models.question import Question, QuestionStatus
from app.models.user import User, UserRole
from app.schemas.governance import FreshnessStatus
from app.services.freshness import answer_freshness


async def seed_governance(session_factory):
    async with session_factory() as session:
        organisation = Organisation(name="Governance Council", slug="governance")
        other_organisation = Organisation(name="Other Governance", slug="other-governance")
        session.add_all([organisation, other_organisation])
        await session.flush()
        finance = Department(organisation_id=organisation.id, name="Finance")
        people = Department(organisation_id=organisation.id, name="People")
        session.add_all([finance, people])
        await session.flush()
        employee = User(
            organisation_id=organisation.id,
            department_id=finance.id,
            email="employee@governance.test",
            display_name="Employee",
        )
        finance_owner = User(
            organisation_id=organisation.id,
            department_id=finance.id,
            email="finance-owner@governance.test",
            display_name="Finance Owner",
            role=UserRole.ANSWER_OWNER,
        )
        people_owner = User(
            organisation_id=organisation.id,
            department_id=people.id,
            email="people-owner@governance.test",
            display_name="People Owner",
            role=UserRole.ANSWER_OWNER,
        )
        admin = User(
            organisation_id=organisation.id,
            email="admin@governance.test",
            display_name="Admin",
            role=UserRole.ADMIN,
        )
        outsider = User(
            organisation_id=other_organisation.id,
            email="outsider@governance.test",
            display_name="Outsider",
            role=UserRole.ADMIN,
        )
        session.add_all([employee, finance_owner, people_owner, admin, outsider])
        await session.flush()
        session.add_all(
            [
                DepartmentAnswerOwner(
                    organisation_id=organisation.id,
                    department_id=finance.id,
                    user_id=finance_owner.id,
                ),
                DepartmentAnswerOwner(
                    organisation_id=organisation.id,
                    department_id=people.id,
                    user_id=people_owner.id,
                ),
            ]
        )
        finance_question = Question(
            organisation_id=organisation.id,
            department_id=finance.id,
            author_id=employee.id,
            title="How do I claim mileage?",
            status=QuestionStatus.ANSWERED,
        )
        people_question = Question(
            organisation_id=organisation.id,
            department_id=people.id,
            author_id=employee.id,
            title="How do I update my address?",
            status=QuestionStatus.ANSWERED,
        )
        session.add_all([finance_question, people_question])
        await session.flush()
        finance_answer = Answer(
            organisation_id=organisation.id,
            question_id=finance_question.id,
            author_id=employee.id,
            body="Use the mileage form.",
            status=AnswerStatus.COMMUNITY,
        )
        replacement_answer = Answer(
            organisation_id=organisation.id,
            question_id=finance_question.id,
            author_id=employee.id,
            body="Use the new mileage portal.",
            status=AnswerStatus.COMMUNITY,
        )
        people_answer = Answer(
            organisation_id=organisation.id,
            question_id=people_question.id,
            author_id=employee.id,
            body="Use the people portal.",
            status=AnswerStatus.COMMUNITY,
        )
        session.add_all([finance_answer, replacement_answer, people_answer])
        await session.commit()
        return {
            "organisation": organisation.id,
            "other_organisation": other_organisation.id,
            "employee": employee.id,
            "finance_owner": finance_owner.id,
            "people_owner": people_owner.id,
            "admin": admin.id,
            "outsider": outsider.id,
            "finance_department": finance.id,
            "people_department": people.id,
            "finance_question": finance_question.id,
            "finance_answer": finance_answer.id,
            "replacement_answer": replacement_answer.id,
            "people_answer": people_answer.id,
        }


def headers(ids, user_key="admin", organisation_key="organisation"):
    return {
        "X-Organisation-ID": str(ids[organisation_key]),
        "X-User-ID": str(ids[user_key]),
    }


@pytest.mark.asyncio
async def test_verification_permissions_metadata_and_audit(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    employee = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/verify",
        headers=headers(ids, "employee"),
        json={},
    )
    assert employee.status_code == 403

    unauthorised_owner = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/verify",
        headers=headers(ids, "people_owner"),
        json={},
    )
    assert unauthorised_owner.status_code == 403

    verified = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/verify",
        headers=headers(ids, "finance_owner"),
        json={"review_days": 90},
    )
    assert verified.status_code == 200
    body = verified.json()
    assert body["status"] == "verified"
    assert body["verified_by"] == str(ids["finance_owner"])
    assert body["verified_at"] is not None
    assert body["last_reviewed_by"] == str(ids["finance_owner"])
    assert body["review_due_at"] is not None

    admin_verified = await client.post(
        f"/api/v1/answers/{ids['people_answer']}/verify",
        headers=headers(ids),
        json={},
    )
    assert admin_verified.status_code == 200

    async with session_factory() as session:
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.ANSWER_VERIFIED.value in actions
        assert AuditAction.ANSWER_VERSION_CREATED.value in actions


@pytest.mark.asyncio
async def test_replacing_verified_answer_supersedes_and_versions(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    for answer_id in (ids["finance_answer"], ids["replacement_answer"]):
        response = await client.post(
            f"/api/v1/answers/{answer_id}/verify",
            headers=headers(ids),
            json={},
        )
        assert response.status_code == 200

    async with session_factory() as session:
        previous = await session.get(Answer, ids["finance_answer"])
        replacement = await session.get(Answer, ids["replacement_answer"])
        question = await session.get(Question, ids["finance_question"])
        assert previous.status == AnswerStatus.SUPERSEDED
        assert replacement.status == AnswerStatus.VERIFIED
        assert question.accepted_answer_id == replacement.id
        assert await session.scalar(select(func.count(AnswerVersion.id))) == 3

    versions = await client.get(
        f"/api/v1/answers/{ids['replacement_answer']}/versions",
        headers=headers(ids, "employee"),
    )
    assert versions.status_code == 200
    assert [item["version_number"] for item in versions.json()] == [3, 2, 1]


@pytest.mark.asyncio
async def test_challenge_accept_replaces_answer_and_reject_is_final(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/verify",
        headers=headers(ids),
        json={},
    )
    challenge = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/challenges",
        headers=headers(ids, "employee"),
        json={
            "type": "outdated",
            "reason": "The process changed.",
            "suggested_answer": "Use the September mileage portal.",
        },
    )
    assert challenge.status_code == 201

    detail = await client.get(
        f"/api/v1/questions/{ids['finance_question']}",
        headers=headers(ids),
        params={"organisation_id": str(ids["organisation"])},
    )
    assert detail.json()["accepted_answer"]["freshness_status"] == "challenged"
    assert detail.json()["accepted_answer"]["has_open_challenge"] is True

    accepted = await client.post(
        f"/api/v1/challenges/{challenge.json()['id']}/accept",
        headers=headers(ids, "finance_owner"),
        json={},
    )
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "accepted"

    repeated = await client.post(
        f"/api/v1/challenges/{challenge.json()['id']}/reject",
        headers=headers(ids, "finance_owner"),
        json={},
    )
    assert repeated.status_code == 409

    async with session_factory() as session:
        previous = await session.get(Answer, ids["finance_answer"])
        assert previous.status == AnswerStatus.SUPERSEDED
        current = (
            await session.execute(
                select(Answer).where(
                    Answer.question_id == ids["finance_question"],
                    Answer.status == AnswerStatus.VERIFIED,
                )
            )
        ).scalar_one()
        assert current.body == "Use the September mileage portal."


@pytest.mark.asyncio
async def test_review_updates_freshness_without_new_version(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/verify",
        headers=headers(ids),
        json={},
    )
    async with session_factory() as session:
        version_count = await session.scalar(select(func.count(AnswerVersion.id)))

    reviewed = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/review",
        headers=headers(ids),
        json={"review_days": 365},
    )
    assert reviewed.status_code == 200
    async with session_factory() as session:
        assert await session.scalar(select(func.count(AnswerVersion.id))) == version_count

    answer = Answer(status=AnswerStatus.VERIFIED, review_due_at=datetime(2026, 1, 1))
    assert answer_freshness(
        answer,
        has_open_challenge=False,
        now=datetime(2026, 2, 1, tzinfo=UTC),
    ) == FreshnessStatus.OVERDUE
    answer.review_due_at = datetime(2026, 2, 20)
    assert answer_freshness(
        answer,
        has_open_challenge=False,
        now=datetime(2026, 2, 1, tzinfo=UTC),
        due_soon_days=30,
    ) == FreshnessStatus.REVIEW_DUE_SOON


@pytest.mark.asyncio
async def test_review_queue_and_cross_tenant_access(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    employee_queue = await client.get(
        "/api/v1/review-queue", headers=headers(ids, "employee")
    )
    assert employee_queue.status_code == 403

    finance_queue = await client.get(
        "/api/v1/review-queue", headers=headers(ids, "finance_owner")
    )
    assert finance_queue.status_code == 200
    assert {item["question_id"] for item in finance_queue.json()} == {
        str(ids["finance_question"])
    }

    challenge = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/challenges",
        headers=headers(ids, "employee"),
        json={"type": "incorrect", "reason": "Needs checking"},
    )
    await client.post(
        f"/api/v1/challenges/{challenge.json()['id']}/reject",
        headers=headers(ids, "finance_owner"),
        json={"reason": "The published answer remains correct"},
    )
    rejected_queue = await client.get(
        "/api/v1/review-queue",
        params={"status": "rejected"},
        headers=headers(ids, "finance_owner"),
    )
    assert len(rejected_queue.json()) == 1
    assert rejected_queue.json()[0]["challenge_status"] == "rejected"

    foreign_challenge = await client.post(
        f"/api/v1/answers/{ids['finance_answer']}/challenges",
        headers=headers(ids, "outsider", "other_organisation"),
        json={"type": "incorrect", "reason": "Foreign tenant"},
    )
    assert foreign_challenge.status_code == 404
    foreign_versions = await client.get(
        f"/api/v1/answers/{ids['finance_answer']}/versions",
        headers=headers(ids, "outsider", "other_organisation"),
    )
    assert foreign_versions.status_code == 404
    foreign_audit = await client.get(
        "/api/v1/audit-events",
        headers=headers(ids, "outsider", "other_organisation"),
    )
    assert foreign_audit.status_code == 200
    assert foreign_audit.json() == []


@pytest.mark.asyncio
async def test_admin_assigns_and_removes_department_owner(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    forbidden = await client.post(
        f"/api/v1/departments/{ids['finance_department']}/answer-owners",
        headers=headers(ids, "employee"),
        json={"user_id": str(ids["people_owner"])},
    )
    assert forbidden.status_code == 403

    assigned = await client.post(
        f"/api/v1/departments/{ids['finance_department']}/answer-owners",
        headers=headers(ids),
        json={"user_id": str(ids["people_owner"])},
    )
    assert assigned.status_code == 201
    assert assigned.json()["department"]["id"] == str(ids["finance_department"])

    owners = await client.get(
        "/api/v1/department-answer-owners", headers=headers(ids)
    )
    assert owners.status_code == 200
    assert any(
        item["department"]["id"] == str(ids["finance_department"])
        and item["user"]["id"] == str(ids["people_owner"])
        for item in owners.json()
    )

    finance_owner_departments = await client.get(
        "/api/v1/department-answer-owners/mine",
        headers=headers(ids, "finance_owner"),
    )
    assert finance_owner_departments.status_code == 200
    assert finance_owner_departments.json() == [str(ids["finance_department"])]

    people_owner_departments = await client.get(
        "/api/v1/department-answer-owners/mine",
        headers=headers(ids, "people_owner"),
    )
    assert people_owner_departments.status_code == 200
    assert set(people_owner_departments.json()) == {
        str(ids["finance_department"]),
        str(ids["people_department"]),
    }

    employee_departments = await client.get(
        "/api/v1/department-answer-owners/mine",
        headers=headers(ids, "employee"),
    )
    assert employee_departments.status_code == 403

    removed = await client.delete(
        f"/api/v1/departments/{ids['finance_department']}/answer-owners/"
        f"{ids['people_owner']}",
        headers=headers(ids),
    )
    assert removed.status_code == 204
    remaining_owner_departments = await client.get(
        "/api/v1/department-answer-owners/mine",
        headers=headers(ids, "people_owner"),
    )
    assert remaining_owner_departments.status_code == 200
    assert remaining_owner_departments.json() == [str(ids["people_department"])]

    async with session_factory() as session:
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.DEPARTMENT_OWNER_ASSIGNED.value in actions
        assert AuditAction.DEPARTMENT_OWNER_REMOVED.value in actions