import os
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.models import Base
from app.models.answer import Answer, AnswerStatus
from app.models.guest import (
    GuestGroup,
    GuestGroupEntry,
    GuestGroupMembership,
)
from app.models.organisation import Organisation
from app.models.personal_workspace import PersonalWorkspaceItem
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.ai.embedding_service import embedding_source_hash
from app.ai.private_knowledge_embedding import private_knowledge_text
from app.repositories.search import SearchRepository
from app.services.guest import GuestService
from app.services.personal_workspace import PersonalWorkspaceService


class FixedEmbeddingProvider:
    model_name = "test-real-embedding"
    dimensions = 1536

    async def embed_text(self, _text: str) -> list[float]:
        return [1.0] + [0.0] * (self.dimensions - 1)


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
                await connection.execute(
                    text(
                        "CREATE EXTENSION IF NOT EXISTS pg_trgm "
                        f'WITH SCHEMA "{schema_name}"'
                    )
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

                    answer_candidates = await SearchRepository(
                        session
                    ).lexical_candidates(
                        organisation_id=organisation.id,
                        actor=user,
                        query_text="checklist",
                        limit=5,
                    )
                    assert answer_candidates
                    assert answer_candidates[0][0].id == question.id

                    typo_candidates = await SearchRepository(
                        session
                    ).lexical_candidates(
                        organisation_id=organisation.id,
                        actor=user,
                        query_text="handoverr",
                        limit=5,
                    )
                    assert typo_candidates
                    assert typo_candidates[0][0].id == question.id
            finally:
                await connection.rollback()
                await connection.execute(
                    text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
                )
                await connection.commit()
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_private_semantic_search_is_owner_and_membership_scoped() -> None:
    database_url = os.environ.get("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is not configured")

    engine = create_async_engine(database_url)
    schema_name = f"private_search_test_{uuid4().hex}"
    provider = FixedEmbeddingProvider()
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
                    vector = await provider.embed_text("semantic query")
                    personal_items = []
                    for uid in ("personal-owner-a", "personal-owner-b"):
                        title = f"Private record {uid}"
                        data = {
                            "id": uid,
                            "title": title,
                            "body": "Content unrelated to the query",
                        }
                        personal_items.append(
                            PersonalWorkspaceItem(
                                firebase_uid=uid,
                                source_key=f"knowledge:{uid}",
                                kind="knowledge",
                                title=title,
                                data=data,
                                revision=1,
                                knowledge_embedding=vector,
                                embedding_model=provider.model_name,
                                embedding_source_hash=embedding_source_hash(
                                    private_knowledge_text(title, data),
                                    provider.model_name,
                                ),
                            )
                        )
                    session.add_all(personal_items)
                    ranking_items = []
                    for title, body in (
                        ("Safety guidance", "Use the vault recovery phrase."),
                        ("Semantic-only match", "General reference material."),
                    ):
                        data = {"id": title.casefold().replace(" ", "-"), "body": body}
                        ranking_items.append(
                            PersonalWorkspaceItem(
                                firebase_uid="rank-owner",
                                source_key=f"knowledge:{data['id']}",
                                kind="knowledge",
                                title=title,
                                data=data,
                                revision=1,
                                knowledge_embedding=vector,
                                embedding_model=provider.model_name,
                                embedding_source_hash=embedding_source_hash(
                                    private_knowledge_text(title, data),
                                    provider.model_name,
                                ),
                            )
                        )
                    session.add_all(ranking_items)

                    entries = []
                    for uid in ("group-owner-a", "group-owner-b"):
                        group = GuestGroup(
                            name=f"Group for {uid}",
                            created_by_uid=uid,
                            expires_at=datetime.now(UTC) + timedelta(days=1),
                        )
                        session.add(group)
                        await session.flush()
                        session.add(
                            GuestGroupMembership(
                                group_id=group.id,
                                firebase_uid=uid,
                                display_name=uid,
                                role="admin",
                                status="active",
                                approved_by_uid=uid,
                            )
                        )
                        title = f"Group record {uid}"
                        data = {"body": "Content unrelated to the query"}
                        entries.append(
                            GuestGroupEntry(
                                group_id=group.id,
                                kind="knowledge",
                                title=title,
                                data=data,
                                created_by_uid=uid,
                                updated_by_uid=uid,
                                revision=1,
                                knowledge_embedding=vector,
                                embedding_model=provider.model_name,
                                embedding_source_hash=embedding_source_hash(
                                    private_knowledge_text(title, data),
                                    provider.model_name,
                                ),
                            )
                        )
                    session.add_all(entries)
                    await session.commit()

                    owner_results = await PersonalWorkspaceService(
                        session, provider
                    ).search_knowledge("personal-owner-a", "semantic query")
                    assert [
                        item["title"] for item in owner_results["results"]
                    ] == ["Private record personal-owner-a"]
                    outsider_results = await PersonalWorkspaceService(
                        session, provider
                    ).search_knowledge("personal-outsider", "semantic query")
                    assert outsider_results == {"results": [], "partial": False}
                    typo_results = await PersonalWorkspaceService(
                        session, provider
                    ).search_knowledge("personal-owner-a", "privte rec")
                    assert typo_results["results"][0]["title"] == (
                        "Private record personal-owner-a"
                    )
                    assert typo_results["results"][0]["match_method"] == "hybrid"
                    ranking_results = await PersonalWorkspaceService(
                        session, provider
                    ).search_knowledge("rank-owner", "vault recovery phrase")
                    assert [
                        item["title"] for item in ranking_results["results"]
                    ] == ["Safety guidance", "Semantic-only match"]
                    assert (
                        ranking_results["results"][0]["relevance_score"]
                        > ranking_results["results"][1]["relevance_score"]
                    )

                    member_results = await GuestService(
                        session, provider
                    ).search_member_knowledge("group-owner-a", "semantic query")
                    assert [
                        item["title"] for item in member_results["results"]
                    ] == ["Group record group-owner-a"]
                    typo_group_results = await GuestService(
                        session, provider
                    ).search_member_knowledge("group-owner-a", "grop recor")
                    assert typo_group_results["results"][0]["title"] == (
                        "Group record group-owner-a"
                    )
                    assert (
                        typo_group_results["results"][0]["match_method"] == "hybrid"
                    )
                    nonmember_results = await GuestService(
                        session, provider
                    ).search_member_knowledge(
                        "group-outsider", "semantic query"
                    )
                    assert nonmember_results == {"results": [], "partial": False}
            finally:
                await connection.rollback()
                await connection.execute(
                    text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
                )
                await connection.commit()
    finally:
        await engine.dispose()
