import os

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.question import Question, QuestionVisibility
from app.models.question_version import QuestionVersion
from app.models.team_membership import TeamMembership
from app.repositories.search import SearchRepository
from app.repositories.user import UserRepository
from app.services.permissions import PermissionService
from tests.test_question_visibility import seed_scope


@pytest.mark.asyncio
async def test_native_enum_scope_filter_and_version_survive_migration():
    url = os.getenv('KNOWLEDGE_TEST_POSTGRES_URL')
    if not url:
        pytest.skip('Requires isolated PostgreSQL migration test database')
    engine = create_async_engine(url)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        ids = await seed_scope(factory)
        async with factory() as session:
            question = await session.get(Question, ids['finance_question'])
            question.visibility = QuestionVisibility.TEAM
            question.team_id = ids['team']
            session.add(QuestionVersion(
                organisation_id=ids['organisation'], question_id=question.id,
                version_number=1, title=question.title, body=question.body,
                status_snapshot=question.status, visibility_snapshot=question.visibility,
                team_id=question.team_id, changed_by=ids['employee'], change_reason='F12 migration',
            ))
            await session.commit()
        async with factory() as session:
            permissions = PermissionService(UserRepository(session))
            question = await session.get(Question, ids['finance_question'])
            for name, allowed in [('employee', True), ('finance_owner', True), ('people_owner', False), ('admin', False)]:
                actor = await permissions.actor(ids[name], ids['organisation'])
                assert await permissions.can_view_question(actor, question) == allowed
                results = await SearchRepository(session).lexical_candidates(
                    organisation_id=ids['organisation'], actor=actor, query_text=question.title,
                    limit=5, include_unanswered=True,
                )
                assert (question.id in {row[1].id for row in results}) == allowed
            await session.execute(delete(TeamMembership).where(
                TeamMembership.team_id == ids['team'], TeamMembership.user_id == ids['employee']))
            await session.commit()
        async with factory() as session:
            permissions = PermissionService(UserRepository(session))
            actor = await permissions.actor(ids['employee'], ids['organisation'])
            question = await session.get(Question, ids['finance_question'])
            assert not await permissions.can_view_question(actor, question)
            version = await session.scalar(select(QuestionVersion).where(QuestionVersion.question_id == question.id))
            assert version.visibility_snapshot == QuestionVisibility.TEAM
    finally:
        await engine.dispose()
