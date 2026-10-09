import asyncio

import pytest
from app.core.exceptions import ConflictError
from app.models.guided import (
    GuidedAnswer,
    GuidedQuestion,
    GuidedSession,
    GuidedSessionRevision,
)
from app.repositories.guided import GuidedRepository
from app.schemas.guided import (
    GuidedAnswerUpdate,
    GuidedAnswerUpsert,
    GuidedParticipantCreate,
    GuidedQuestionCreate,
    GuidedQuestionUpdate,
    GuidedSessionCreate,
)
from app.services.guided import GuidedService
from sqlalchemy import func, select, text

from tests import test_organisation_administration_postgres as postgres_tests

postgres_sessions = postgres_tests.postgres_sessions
seed_postgres = postgres_tests.seed_postgres


@pytest.mark.asyncio
@pytest.mark.parametrize("first", ["answer", "question"])
async def test_postgres_guided_concurrent_edits_reject_stale_revision(postgres_sessions, monkeypatch, first):
    ids = await seed_postgres(postgres_sessions)
    organisation_id, actor_id = ids["organisation_id"], ids["member"]
    async with postgres_sessions() as session:
        service = GuidedService(session)
        guided = await service.create_session(organisation_id, actor_id, GuidedSessionCreate(title="Concurrency"))
        participant = await service.add_participant(guided.id, organisation_id, actor_id, GuidedParticipantCreate(name="Alice"))
        question = await service.add_question(guided.id, organisation_id, actor_id, GuidedQuestionCreate(text="Original question", scope="shared"))
        answer = await service.upsert_answer(question.id, organisation_id, actor_id, GuidedAnswerUpsert(participant_id=participant.id, body="Original answer"))
        revision = answer.session_revision
        before = await session.scalar(select(func.count()).select_from(GuidedSessionRevision))
    locked = asyncio.Event()
    release = asyncio.Event()
    original = GuidedRepository.guided_session

    async def gated(self, *args, **kwargs):
        result = await original(self, *args, **kwargs)
        if kwargs.get("for_update") and not locked.is_set():
            locked.set()
            await asyncio.wait_for(release.wait(), 5)
        return result

    monkeypatch.setattr(GuidedRepository, "guided_session", gated)

    async def edit(kind):
        async with postgres_sessions() as session:
            await session.execute(text("SET LOCAL lock_timeout = '5s'"))
            service = GuidedService(session)
            try:
                if kind == "answer":
                    await service.update_answer(answer.id, organisation_id, actor_id, GuidedAnswerUpdate(body="", expected_revision=revision))
                else:
                    await service.update_question(question.id, organisation_id, actor_id, GuidedQuestionUpdate(text="Changed question", expected_revision=revision))
                return "saved"
            except ConflictError:
                await session.rollback()
                return "conflict"

    first_task = asyncio.create_task(edit(first))
    second_task = None
    try:
        await asyncio.wait_for(locked.wait(), 5)
        second = "question" if first == "answer" else "answer"
        second_task = asyncio.create_task(edit(second))
        await asyncio.sleep(0)
        release.set()
        assert await asyncio.wait_for(asyncio.gather(first_task, second_task), 10) == ["saved", "conflict"]
    finally:
        release.set()
        for task in (first_task, second_task):
            if task is not None and not task.done():
                task.cancel()
        await asyncio.gather(*(task for task in (first_task, second_task) if task is not None), return_exceptions=True)
    async with postgres_sessions() as session:
        assert (await session.get(GuidedSession, guided.id)).revision == revision + 1
        assert (await session.get(GuidedQuestion, question.id)).text == ("Changed question" if first == "question" else "Original question")
        assert (await session.get(GuidedAnswer, answer.id)).body == ("" if first == "answer" else "Original answer")
        assert await session.scalar(select(func.count()).select_from(GuidedSessionRevision)) == before + 1


@pytest.mark.asyncio
async def test_postgres_concurrent_knowledge_submissions_share_pending_proposal(postgres_sessions):
    from app.models.guided import KnowledgeProposal
    from app.schemas.guided import KnowledgeProposalCreate
    from app.services.guided_knowledge import GuidedKnowledgeService

    ids = await seed_postgres(postgres_sessions)
    organisation_id, actor_id = ids["organisation_id"], ids["member"]
    async with postgres_sessions() as session:
        service = GuidedService(session)
        guided = await service.create_session(organisation_id, actor_id, GuidedSessionCreate(title="Proposal concurrency"))
        participant = await service.add_participant(guided.id, organisation_id, actor_id, GuidedParticipantCreate(name="Alice"))
        question = await service.add_question(guided.id, organisation_id, actor_id, GuidedQuestionCreate(text="Question", scope="shared"))
        answer = await service.upsert_answer(question.id, organisation_id, actor_id, GuidedAnswerUpsert(participant_id=participant.id, body="Answer"))
        payload = KnowledgeProposalCreate(guided_question_id=question.id, guided_answer_id=answer.id)

    async def submit():
        async with postgres_sessions() as session:
            return await GuidedKnowledgeService(session).create_proposal(organisation_id, actor_id, payload)

    results = await asyncio.wait_for(asyncio.gather(submit(), submit()), timeout=10)
    assert results[0].id == results[1].id
    assert sorted(r.already_pending for r in results) == [False, True]
    async with postgres_sessions() as session:
        assert await session.scalar(select(func.count()).select_from(KnowledgeProposal).where(KnowledgeProposal.guided_answer_id == answer.id)) == 1
