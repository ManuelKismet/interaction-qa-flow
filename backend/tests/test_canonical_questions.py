from datetime import UTC, datetime
from uuid import UUID

import pytest
from sqlalchemy import select

from app.models.answer import Answer, AnswerStatus
from app.models.audit_event import AuditAction, AuditEvent
from app.models.duplicate_suggestion import DuplicateSuggestion
from app.models.question import Question, QuestionStatus, QuestionVisibility
from app.services import canonical as canonical_module
from tests.test_answer_governance import headers, seed_governance


async def add_question(
    session_factory,
    ids,
    title,
    *,
    organisation_key="organisation",
    author_key="employee",
    body=None,
    with_answer=False,
    verified=False,
):
    async with session_factory() as session:
        question = Question(
            organisation_id=ids[organisation_key],
            department_id=ids["finance_department"]
            if organisation_key == "organisation"
            else None,
            author_id=ids[author_key],
            title=title,
            body=body,
            status=QuestionStatus.RESOLVED if with_answer else QuestionStatus.OPEN,
            visibility=QuestionVisibility.ORGANISATION,
            resolved_at=datetime.now(UTC) if with_answer else None,
        )
        session.add(question)
        await session.flush()
        answer = None
        if with_answer:
            answer = Answer(
                organisation_id=ids[organisation_key],
                question_id=question.id,
                author_id=ids[author_key],
                body=f"Answer for {title}",
                status=AnswerStatus.VERIFIED if verified else AnswerStatus.COMMUNITY,
                verified_by=ids[author_key] if verified else None,
                verified_at=datetime.now(UTC) if verified else None,
            )
            session.add(answer)
            await session.flush()
            question.accepted_answer_id = answer.id
        await session.commit()
        return question.id, answer.id if answer else None


@pytest.mark.asyncio
async def test_owner_merges_multiple_questions_and_preserves_history(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    first_id, _ = await add_question(
        session_factory,
        ids,
        "Where do I book holiday?",
        body="Original employee wording one",
    )
    second_id, _ = await add_question(
        session_factory,
        ids,
        "How do I submit leave?",
        body="Original employee wording two",
    )

    denied = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids, "employee"),
        json={
            "duplicate_question_ids": [str(first_id)],
            "reason": "Same leave process",
        },
    )
    assert denied.status_code == 403

    merged = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids, "finance_owner"),
        json={
            "duplicate_question_ids": [str(first_id), str(second_id)],
            "reason": "Same leave process",
        },
    )
    assert merged.status_code == 200
    assert set(merged.json()["merged_question_ids"]) == {str(first_id), str(second_id)}

    async with session_factory() as session:
        first = await session.get(Question, first_id)
        second = await session.get(Question, second_id)
        assert first.canonical_question_id == ids["finance_question"]
        assert second.canonical_question_id == ids["finance_question"]
        assert first.title == "Where do I book holiday?"
        assert first.body == "Original employee wording one"
        actions = list(await session.scalars(select(AuditEvent.action)))
        assert actions.count(AuditAction.QUESTION_MERGED.value) == 2

    detail = await client.get(
        f"/api/v1/questions/{ids['finance_question']}",
        headers=headers(ids, "finance_owner"),
        params={"organisation_id": str(ids["organisation"])},
    )
    assert {alias["title"] for alias in detail.json()["aliases"]} == {
        "Where do I book holiday?",
        "How do I submit leave?",
    }


@pytest.mark.asyncio
async def test_merge_and_unmerge_refresh_canonical_search_embeddings(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    alias_id, _ = await add_question(
        session_factory, ids, "Where do I find the travel policy?"
    )
    synced_questions = []

    async def record_sync(_service, question):
        synced_questions.append(question.id)
        return True

    monkeypatch.setattr(
        canonical_module.EmbeddingService, "sync_question", record_sync
    )
    merged = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids, "finance_owner"),
        json={
            "duplicate_question_ids": [str(alias_id)],
            "reason": "Same travel process",
        },
    )
    assert merged.status_code == 200, merged.text
    unmerged = await client.post(
        f"/api/v1/questions/{alias_id}/unmerge",
        headers=headers(ids, "finance_owner"),
        json={"reason": "Search content should stand alone"},
    )
    assert unmerged.status_code == 200, unmerged.text
    assert synced_questions == [
        ids["finance_question"],
        alias_id,
        ids["finance_question"],
    ]


@pytest.mark.asyncio
async def test_answer_conflict_requires_selection_and_copies_without_moving(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    canonical_id, canonical_answer_id = await add_question(
        session_factory, ids, "Annual leave", with_answer=True, verified=True
    )
    duplicate_id, duplicate_answer_id = await add_question(
        session_factory, ids, "Holiday booking", with_answer=True, verified=True
    )
    payload = {
        "duplicate_question_ids": [str(duplicate_id)],
        "reason": "Equivalent policy",
    }
    conflict = await client.post(
        f"/api/v1/questions/{canonical_id}/merge",
        headers=headers(ids),
        json=payload,
    )
    assert conflict.status_code == 409

    selected = await client.post(
        f"/api/v1/questions/{canonical_id}/merge",
        headers=headers(ids),
        json={**payload, "canonical_answer_id": str(duplicate_answer_id)},
    )
    assert selected.status_code == 200
    copied_answer_id = selected.json()["canonical_answer_id"]
    assert copied_answer_id not in {str(canonical_answer_id), str(duplicate_answer_id)}

    async with session_factory() as session:
        duplicate = await session.get(Question, duplicate_id)
        original = await session.get(Answer, duplicate_answer_id)
        previous = await session.get(Answer, canonical_answer_id)
        copied = await session.get(Answer, UUID(copied_answer_id))
        assert duplicate.accepted_answer_id == duplicate_answer_id
        assert original.question_id == duplicate_id
        assert original.status == AnswerStatus.VERIFIED
        assert previous.status == AnswerStatus.SUPERSEDED
        assert copied.question_id == canonical_id
        assert copied.body == original.body
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.CANONICAL_ANSWER_CHANGED.value in actions


@pytest.mark.asyncio
async def test_merge_rejects_self_cross_tenant_and_cycles(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    foreign_id, _ = await add_question(
        session_factory,
        ids,
        "Foreign question",
        organisation_key="other_organisation",
        author_key="outsider",
    )
    self_merge = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids),
        json={
            "duplicate_question_ids": [str(ids["finance_question"])],
            "reason": "Invalid",
        },
    )
    assert self_merge.status_code == 409
    cross_tenant = await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids),
        json={"duplicate_question_ids": [str(foreign_id)], "reason": "Invalid"},
    )
    assert cross_tenant.status_code == 404

    first_id, _ = await add_question(session_factory, ids, "Cycle one")
    second_id, _ = await add_question(session_factory, ids, "Cycle two")
    async with session_factory() as session:
        first = await session.get(Question, first_id)
        second = await session.get(Question, second_id)
        first.canonical_question_id = second.id
        second.canonical_question_id = first.id
        await session.commit()
    cycle = await client.post(
        f"/api/v1/questions/{first_id}/merge",
        headers=headers(ids),
        json={
            "duplicate_question_ids": [str(ids["finance_question"])],
            "reason": "Invalid",
        },
    )
    assert cycle.status_code == 409


@pytest.mark.asyncio
async def test_unmerge_restores_independent_question(app_client) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    duplicate_id, _ = await add_question(
        session_factory, ids, "Independent history", body="Keep this body"
    )
    await client.post(
        f"/api/v1/questions/{ids['finance_question']}/merge",
        headers=headers(ids),
        json={
            "duplicate_question_ids": [str(duplicate_id)],
            "reason": "Initially considered duplicate",
        },
    )
    response = await client.post(
        f"/api/v1/questions/{duplicate_id}/unmerge",
        headers=headers(ids),
        json={"reason": "Different policy after all"},
    )
    assert response.status_code == 200
    assert response.json()["canonical_question_id"] is None
    assert response.json()["body"] == "Keep this body"


@pytest.mark.asyncio
async def test_employee_suggestion_appears_in_queue_and_can_be_rejected(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    synced_questions = []

    async def record_sync(_service, question):
        synced_questions.append(question.id)
        return True

    monkeypatch.setattr(
        canonical_module.EmbeddingService, "sync_question", record_sync
    )
    duplicate_id, _ = await add_question(session_factory, ids, "Possible duplicate")
    suggestion = await client.post(
        f"/api/v1/questions/{duplicate_id}/duplicate-suggestions",
        headers=headers(ids, "employee"),
        json={
            "suggested_canonical_question_id": str(ids["finance_question"]),
            "reason": "I found the same policy",
        },
    )
    assert suggestion.status_code == 201
    queue = await client.get(
        "/api/v1/review-queue",
        headers=headers(ids, "finance_owner"),
        params={"type": "duplicate_suggestion"},
    )
    assert queue.status_code == 200
    assert queue.json()[0]["duplicate_suggestion_id"] == suggestion.json()["id"]

    rejected = await client.post(
        f"/api/v1/duplicate-suggestions/{suggestion.json()['id']}/reject",
        headers=headers(ids, "finance_owner"),
        json={"reason": "Different process"},
    )
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "rejected"

    resubmitted = await client.post(
        f"/api/v1/questions/{duplicate_id}/duplicate-suggestions",
        headers=headers(ids, "employee"),
        json={
            "suggested_canonical_question_id": str(ids["finance_question"]),
            "reason": "Please reconsider with new context",
        },
    )
    assert resubmitted.status_code == 201
    accepted = await client.post(
        f"/api/v1/duplicate-suggestions/{resubmitted.json()['id']}/accept",
        headers=headers(ids, "finance_owner"),
        json={"reason": "Confirmed duplicate"},
    )
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "accepted"
    assert synced_questions == [ids["finance_question"]]

    async with session_factory() as session:
        duplicate = await session.get(Question, duplicate_id)
        assert duplicate.canonical_question_id == ids["finance_question"]
        actions = set(await session.scalars(select(AuditEvent.action)))
        assert AuditAction.DUPLICATE_SUGGESTED.value in actions
        assert AuditAction.DUPLICATE_SUGGESTION_REJECTED.value in actions
        assert AuditAction.DUPLICATE_SUGGESTION_ACCEPTED.value in actions


@pytest.mark.asyncio
async def test_duplicate_suggestion_cannot_resolve_visible_alias_to_private_root(
    app_client,
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    async with session_factory() as session:
        private_root = Question(
            organisation_id=ids["organisation"],
            author_id=ids["employee"],
            title="Private canonical root",
            visibility=QuestionVisibility.PRIVATE,
        )
        session.add(private_root)
        await session.flush()
        visible_alias = Question(
            organisation_id=ids["organisation"],
            author_id=ids["employee"],
            title="Visible alias of private root",
            visibility=QuestionVisibility.ORGANISATION,
            canonical_question_id=private_root.id,
        )
        visible_middle = Question(
            organisation_id=ids["organisation"],
            author_id=ids["employee"],
            title="Visible intermediate alias",
            visibility=QuestionVisibility.ORGANISATION,
            canonical_question_id=private_root.id,
        )
        session.add_all([visible_alias, visible_middle])
        await session.flush()
        chained_alias = Question(
            organisation_id=ids["organisation"],
            author_id=ids["employee"],
            title="Visible alias through intermediate",
            visibility=QuestionVisibility.ORGANISATION,
            canonical_question_id=visible_middle.id,
        )
        session.add(chained_alias)
        await session.commit()
        private_root_id = private_root.id
        visible_alias_id = visible_alias.id
        chained_alias_id = chained_alias.id

    source_id = ids["finance_question"]
    outsider = headers(ids, "people_owner")
    for alias_id in (visible_alias_id, chained_alias_id):
        denied = await client.post(
            f"/api/v1/questions/{source_id}/duplicate-suggestions",
            headers=outsider,
            json={"suggested_canonical_question_id": str(alias_id)},
        )
        assert denied.status_code == 403, denied.text

    async with session_factory() as session:
        suggestions = await session.scalars(select(DuplicateSuggestion.id))
        assert list(suggestions) == []

    hidden_metadata = await client.get(
        f"/api/v1/questions/{chained_alias_id}", headers=outsider
    )
    assert hidden_metadata.status_code == 200, hidden_metadata.text
    assert hidden_metadata.json()["canonical_question"] is None

    owner_suggestion = await client.post(
        f"/api/v1/questions/{source_id}/duplicate-suggestions",
        headers=headers(ids, "employee"),
        json={"suggested_canonical_question_id": str(visible_alias_id)},
    )
    assert owner_suggestion.status_code == 201, owner_suggestion.text
    assert owner_suggestion.json()["suggested_canonical_question_id"] == str(
        private_root_id
    )
    assert owner_suggestion.json()["suggested_canonical_title"] == (
        "Private canonical root"
    )

    visible_root, _ = await add_question(
        session_factory,
        ids,
        "Visible canonical root",
        author_key="employee",
    )
    async with session_factory() as session:
        visible_target_alias = Question(
            organisation_id=ids["organisation"],
            author_id=ids["employee"],
            title="Visible canonical alias",
            visibility=QuestionVisibility.ORGANISATION,
            canonical_question_id=visible_root,
        )
        session.add(visible_target_alias)
        await session.commit()
        visible_target_alias_id = visible_target_alias.id
    visible_suggestion = await client.post(
        f"/api/v1/questions/{source_id}/duplicate-suggestions",
        headers=outsider,
        json={"suggested_canonical_question_id": str(visible_target_alias_id)},
    )
    assert visible_suggestion.status_code == 201, visible_suggestion.text
    assert visible_suggestion.json()["suggested_canonical_question_id"] == str(
        visible_root
    )


@pytest.mark.asyncio
async def test_duplicate_candidates_enforce_visibility_and_tenant(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    ids = await seed_governance(session_factory)
    private_id, _ = await add_question(session_factory, ids, "Private duplicate")
    async with session_factory() as session:
        private = await session.get(Question, private_id)
        private.visibility = QuestionVisibility.PRIVATE
        private.author_id = ids["finance_owner"]
        await session.commit()

    denied = await client.get(
        f"/api/v1/questions/{private_id}/duplicate-candidates",
        headers=headers(ids, "employee"),
    )
    assert denied.status_code == 403
    foreign = await client.get(
        f"/api/v1/questions/{private_id}/duplicate-candidates",
        headers=headers(ids, "outsider", "other_organisation"),
    )
    assert foreign.status_code == 404

    class FakeSearchService:
        def __init__(self, *args, **kwargs):
            pass

        async def search(self, **kwargs):
            return []

    monkeypatch.setattr(canonical_module, "SearchService", FakeSearchService)
    visible = await client.get(
        f"/api/v1/questions/{private_id}/duplicate-candidates",
        headers=headers(ids, "finance_owner"),
    )
    assert visible.status_code == 200
    assert visible.json() == []