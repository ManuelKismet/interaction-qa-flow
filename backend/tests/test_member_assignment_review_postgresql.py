import asyncio

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.exceptions import ConflictError
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.user import User, UserRole
from app.schemas.organisation_member import OrganisationMemberUpdate
from app.services.governance import GovernanceService
from app.services.organisation_member import OrganisationMemberService
from tests import test_organisation_administration_postgres as postgres_tests

postgres_sessions = postgres_tests.postgres_sessions


@pytest.mark.asyncio
async def test_assignment_waiting_for_role_cleanup_cannot_recreate_assignment(postgres_sessions, monkeypatch):
    ids = await postgres_tests.seed_postgres(postgres_sessions)
    async with postgres_sessions() as session:
        member = await session.get(User, ids['member'])
        member.role = UserRole.ANSWER_OWNER
        session.add(DepartmentAnswerOwner(organisation_id=ids['organisation_id'], department_id=ids['department_id'], user_id=member.id))
        await session.commit()
    locked, release = asyncio.Event(), asyncio.Event()
    original_commit = AsyncSession.commit
    async with postgres_sessions() as updating_session:
        async def gated_commit(self):
            if self is updating_session:
                locked.set()
                await asyncio.wait_for(release.wait(), 5)
            await original_commit(self)

        monkeypatch.setattr(AsyncSession, 'commit', gated_commit)

        async def cleanup():
            return await OrganisationMemberService(updating_session).update_member(
                organisation_id=ids['organisation_id'], actor_id=ids['owner_a'], member_id=ids['member'],
                update=OrganisationMemberUpdate(role=UserRole.EMPLOYEE, clear_department_answer_owners=True),
            )

        async def assign():
            async with postgres_sessions() as session:
                try:
                    await GovernanceService(session, Settings()).assign_department_owner(
                        ids['department_id'], ids['organisation_id'], ids['owner_a'], ids['member'],
                    )
                    return 'assigned'
                except ConflictError:
                    await session.rollback()
                    return 'blocked'

        cleanup_task = asyncio.create_task(cleanup())
        assign_task = None
        try:
            await asyncio.wait_for(locked.wait(), 5)
            assign_task = asyncio.create_task(assign())
            await asyncio.sleep(0)
            release.set()
            results = await asyncio.wait_for(asyncio.gather(cleanup_task, assign_task), 10)
            assert results[0]['role'] == UserRole.EMPLOYEE
            assert results[1] == 'blocked'
        finally:
            release.set()
            await asyncio.gather(cleanup_task, *([assign_task] if assign_task else []), return_exceptions=True)
    async with postgres_sessions() as session:
        assert (await session.get(User, ids['member'])).role == UserRole.EMPLOYEE
        assert await session.scalar(select(DepartmentAnswerOwner.id).where(DepartmentAnswerOwner.user_id == ids['member'])) is None
