import os
from uuid import uuid4

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.models import Base
from app.models.answer import Answer, AnswerStatus
from app.models.organisation import Organisation
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.repositories.search import SearchRepository


@pytest.mark.asyncio
async def test_lexical_candidates_execute_on_postgresql() -> None:
    database_url = os.environ.get("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is not configured")

    engine = create_async_engine(database_url)
    schema_name = f"search_test_{uuid4().hex}"
    try:
        async with engine.connect() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema_name}"'))
            await connection.commit()

            try:
                await connection.execute(
                    text(f'SET search_path TO "{schema_name}", public')
                )
                await connection.run_sync(Base.metadata.create_all)
                await connection.commit()

                async with AsyncSession(
                    bind=connection,
                    expire_on_commit=False,
                ) as session:
                    organisation = Organisation(
                        name="PostgreSQL lexical search",
                        slug=f"postgres-lexical-{uuid4().hex}",
                    )
                    session.add(organisation)
                    await session.flush()
                    user = User(
                        organisation_id=organisation.id,
                        email=f"{uuid4().hex}@example.test",
                        display_name="Lexical Search Tester",
                    )
                    session.add(user)
                    await session.flush()
                    question = Question(
                        organisation_id=organisation.id,
                        author_id=user.id,
                        title="Verified handover procedures",
                        body="Steps for a secure shift change.",
                        status=QuestionStatus.ANSWERED,
                    )
                    session.add(question)
                    await session.flush()
                    session.add(
                        Answer(
                            organisation_id=organisation.id,
                            question_id=question.id,
                            author_id=user.id,
                            body="Use the verified handover checklist.",
                            status=AnswerStatus.VERIFIED,
                        )
                    )
                    await session.commit()

                    candidates = await SearchRepository(session).lexical_candidates(
                        organisation_id=organisation.id,
                        actor=user,
                        query_text="verified handover",
                        limit=5,
                    )
                    assert candidates
                    assert candidates[0][0].id == question.id
            finally:
                await connection.rollback()
                await connection.execute(
                    text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
                )
                await connection.commit()
    finally:
        await engine.dispose()
