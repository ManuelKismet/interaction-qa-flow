import pytest
from sqlalchemy import select

from app.models.audit_event import AuditAction, AuditEvent
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.user import User, UserRole
from tests.test_answer_governance import headers, seed_governance
from tests.test_organisation_members import appoint_owner


@pytest.mark.asyncio
@pytest.mark.parametrize('clear', [False, True])
async def test_role_change_keeps_assignments_unless_explicitly_removed(app_client, clear):
    client, factory = app_client
    ids = await seed_governance(factory)
    await appoint_owner(factory, ids)
    async with factory() as session:
        session.add(DepartmentAnswerOwner(
            organisation_id=ids['organisation'], department_id=ids['people_department'],
            user_id=ids['finance_owner'],
        ))
        await session.commit()
        original = list(await session.scalars(select(DepartmentAnswerOwner).where(
            DepartmentAnswerOwner.user_id == ids['finance_owner'],
        )))
        assignment_ids = {item.id for item in original}
    payload = {'role': 'employee'}
    if clear:
        payload['clear_department_answer_owners'] = True
    response = await client.patch(f"/api/v1/auth/members/{ids['finance_owner']}", headers=headers(ids), json=payload)
    assert response.status_code == 200
    assert response.json()['role'] == 'employee'
    async with factory() as session:
        remaining = set(await session.scalars(select(DepartmentAnswerOwner.id).where(
            DepartmentAnswerOwner.user_id == ids['finance_owner'],
        )))
        assert remaining == (set() if clear else assignment_ids)
        assert await session.scalar(select(DepartmentAnswerOwner.id).where(
            DepartmentAnswerOwner.user_id == ids['people_owner'],
        )) is not None
        removals = list(await session.scalars(select(AuditEvent).where(
            AuditEvent.action == AuditAction.DEPARTMENT_OWNER_REMOVED.value,
        )))
        assert {item.entity_id for item in removals} == (assignment_ids if clear else set())
        assert all(item.actor_id == ids['admin'] and item.event_metadata['user_id'] == str(ids['finance_owner']) for item in removals)
    if clear:
        # Repeating explicit cleanup is harmless and creates no duplicate audit.
        assert (await client.patch(f"/api/v1/auth/members/{ids['finance_owner']}", headers=headers(ids), json=payload)).status_code == 200
        # A demoted member cannot be assigned again through the existing API.
        assigned = await client.post(f"/api/v1/departments/{ids['finance_department']}/answer-owners", headers=headers(ids), json={
            'user_id': str(ids['finance_owner']),
        })
        assert assigned.status_code == 409


@pytest.mark.asyncio
async def test_explicit_assignment_cleanup_is_owner_scoped_and_atomic(app_client):
    client, factory = app_client
    ids = await seed_governance(factory)
    path = f"/api/v1/auth/members/{ids['finance_owner']}"
    # Legacy admin cannot use cleanup without role/status to bypass owner checks.
    assert (await client.patch(path, headers=headers(ids), json={'clear_department_answer_owners': True})).status_code == 403
    await appoint_owner(factory, ids)
    assert (await client.patch(f"/api/v1/auth/members/{ids['outsider']}", headers=headers(ids), json={'clear_department_answer_owners': True})).status_code == 404
    response = await client.patch(path, headers=headers(ids), json={
        'role': 'employee', 'department_id': str(ids['other_organisation']),
        'clear_department_answer_owners': True,
    })
    assert response.status_code == 404
    async with factory() as session:
        assert (await session.get(User, ids['finance_owner'])).role == UserRole.ANSWER_OWNER
        assert await session.scalar(select(DepartmentAnswerOwner.id).where(DepartmentAnswerOwner.user_id == ids['finance_owner'])) is not None
        assert await session.scalar(select(AuditEvent.id)) is None
