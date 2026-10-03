import pytest
from sqlalchemy import select

from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.firebase_uid_mapping import FirebaseUidMapping
from app.models.user import User, UserRole
from tests.test_answer_governance import headers, seed_governance


@pytest.mark.asyncio
async def test_organisation_member_management_is_admin_scoped_and_audited(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        second_admin = User(
            organisation_id=ids["organisation"],
            email="second-admin@governance.test",
            display_name="Second Admin",
            role=UserRole.ADMIN,
        )
        foreign_department = Department(
            organisation_id=ids["other_organisation"],
            name="Foreign department",
        )
        session.add_all([second_admin, foreign_department])
        await session.commit()
        second_admin_id = second_admin.id
        foreign_department_id = foreign_department.id

    denied_list = await client.get(
        "/api/v1/auth/members",
        headers=headers(ids, "employee"),
    )
    assert denied_list.status_code == 403
    denied_update = await client.patch(
        f"/api/v1/auth/members/{ids['employee']}",
        headers=headers(ids, "employee"),
        json={"role": "admin"},
    )
    assert denied_update.status_code == 403

    members = await client.get("/api/v1/auth/members", headers=headers(ids))
    assert members.status_code == 200
    assert {member["id"] for member in members.json()} == {
        str(ids["employee"]),
        str(ids["finance_owner"]),
        str(ids["people_owner"]),
        str(ids["admin"]),
        str(second_admin_id),
    }

    foreign_member = await client.patch(
        f"/api/v1/auth/members/{ids['outsider']}",
        headers=headers(ids),
        json={"role": "employee"},
    )
    assert foreign_member.status_code == 404

    foreign_department_update = await client.patch(
        f"/api/v1/auth/members/{ids['employee']}",
        headers=headers(ids),
        json={"department_id": str(foreign_department_id)},
    )
    assert foreign_department_update.status_code == 404
    invalid_combined_update = await client.patch(
        f"/api/v1/auth/members/{ids['employee']}",
        headers=headers(ids),
        json={
            "role": "admin",
            "department_id": str(foreign_department_id),
        },
    )
    assert invalid_combined_update.status_code == 404
    async with session_factory() as session:
        employee = await session.get(User, ids["employee"])
        assert employee is not None
        assert employee.role == UserRole.EMPLOYEE

    promoted = await client.patch(
        f"/api/v1/auth/members/{ids['employee']}",
        headers=headers(ids),
        json={
            "role": "admin",
            "department_id": str(ids["finance_department"]),
        },
    )
    assert promoted.status_code == 200
    assert promoted.json()["role"] == "admin"
    assert promoted.json()["department_id"] == str(ids["finance_department"])
    assert promoted.json()["department_name"] == "Finance"

    async with session_factory() as session:
        role_events = (
            await session.scalars(
                select(AuditEvent).where(
                    AuditEvent.action
                    == AuditAction.ORGANISATION_MEMBER_ROLE_CHANGED.value
                )
            )
        ).all()
        department_event = await session.scalar(
            select(AuditEvent).where(
                AuditEvent.action
                == AuditAction.USER_PRIMARY_DEPARTMENT_CHANGED.value,
                AuditEvent.entity_id == ids["employee"],
            )
        )
        assert len(role_events) == 1
        assert role_events[0].event_metadata == {
            "old_role": "employee",
            "new_role": "admin",
        }
        assert department_event is not None
        assert department_event.actor_id == ids["admin"]


@pytest.mark.asyncio
async def test_last_active_organisation_admin_cannot_be_demoted(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    response = await client.patch(
        f"/api/v1/auth/members/{ids['admin']}",
        headers=headers(ids),
        json={"role": "employee"},
    )

    assert response.status_code == 409
    async with session_factory() as session:
        admin = await session.get(User, ids["admin"])
        assert admin is not None
        assert admin.role == UserRole.ADMIN
        assert await session.scalar(select(AuditEvent.id)) is None


@pytest.mark.asyncio
async def test_admin_adds_only_a_registered_verified_firebase_account(
    app_client,
    monkeypatch,
) -> None:
    from app.api.v1.routes import auth as auth_routes

    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    class VerifiedAccount:
        uid = "verified-new-user"
        email = "new-member@example.test"
        email_verified = True
        display_name = "New Member"

    monkeypatch.setattr(
        auth_routes,
        "firebase_app",
        lambda settings: object(),
    )
    monkeypatch.setattr(
        auth_routes.auth,
        "get_user_by_email",
        lambda email, app: VerifiedAccount(),
    )

    denied = await client.post(
        "/api/v1/auth/members",
        headers=headers(ids, "employee"),
        json={"email": "new-member@example.test"},
    )
    assert denied.status_code == 403

    response = await client.post(
        "/api/v1/auth/members",
        headers=headers(ids),
        json={
            "email": "new-member@example.test",
            "role": "employee",
            "department_id": str(ids["finance_department"]),
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "new-member@example.test"
    assert body["display_name"] == "New Member"
    assert body["role"] == "employee"
    assert body["department_name"] == "Finance"
    async with session_factory() as session:
        mapping = await session.get(FirebaseUidMapping, "verified-new-user")
        event = await session.scalar(
            select(AuditEvent).where(
                AuditEvent.action == AuditAction.ORGANISATION_MEMBER_ADDED.value
            )
        )
        assert mapping is not None
        assert str(mapping.user_id) == body["id"]
        assert event is not None
        assert event.actor_id == ids["admin"]


@pytest.mark.asyncio
async def test_unverified_account_is_not_added(app_client, monkeypatch) -> None:
    from app.api.v1.routes import auth as auth_routes

    client, session_factory = app_client
    ids = await seed_governance(session_factory)

    class UnverifiedAccount:
        uid = "unverified-user"
        email = "unverified@example.test"
        email_verified = False
        display_name = "Unverified"

    monkeypatch.setattr(auth_routes, "firebase_app", lambda settings: object())
    monkeypatch.setattr(
        auth_routes.auth,
        "get_user_by_email",
        lambda email, app: UnverifiedAccount(),
    )
    response = await client.post(
        "/api/v1/auth/members",
        headers=headers(ids),
        json={"email": "unverified@example.test"},
    )

    assert response.status_code == 422
    async with session_factory() as session:
        assert await session.get(FirebaseUidMapping, "unverified-user") is None
        assert await session.scalar(select(AuditEvent.id)) is None
