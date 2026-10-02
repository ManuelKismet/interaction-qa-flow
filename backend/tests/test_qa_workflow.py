import pytest
from sqlalchemy import func, select

from app.models.answer_reaction import AnswerReaction
from app.models.organisation import Organisation
from app.models.user import User, UserRole


async def seed_users(session_factory):
    async with session_factory() as session:
        organisation = Organisation(name="Example Council", slug="workflow-council")
        other_organisation = Organisation(name="Other Council", slug="other-council")
        session.add_all([organisation, other_organisation])
        await session.flush()
        author = User(
            organisation_id=organisation.id,
            email="author@example.test",
            display_name="Question Author",
        )
        contributor = User(
            organisation_id=organisation.id,
            email="contributor@example.test",
            display_name="Contributor",
        )
        admin = User(
            organisation_id=organisation.id,
            email="admin@example.test",
            display_name="Admin User",
            role=UserRole.ADMIN,
        )
        outsider = User(
            organisation_id=other_organisation.id,
            email="outsider@example.test",
            display_name="Outsider",
        )
        session.add_all([author, contributor, admin, outsider])
        await session.commit()
        return {
            "organisation_id": organisation.id,
            "other_organisation_id": other_organisation.id,
            "author_id": author.id,
            "contributor_id": contributor.id,
            "admin_id": admin.id,
            "outsider_id": outsider.id,
        }


async def create_question(client, identities):
    response = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "author_id": str(identities["author_id"]),
            "title": "How do I claim mileage?",
            "body": "I need the current process.",
        },
    )
    assert response.status_code == 201
    return response.json()


async def create_answer(client, identities, question_id):
    response = await client.post(
        f"/api/v1/questions/{question_id}/answers",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "author_id": str(identities["contributor_id"]),
            "body": "Submit the mileage form to Finance.",
        },
    )
    assert response.status_code == 201
    return response.json()


@pytest.mark.asyncio
async def test_answer_resolve_detail_and_reopen(app_client) -> None:
    client, session_factory = app_client
    identities = await seed_users(session_factory)
    question = await create_question(client, identities)
    answer = await create_answer(client, identities, question["id"])

    resolved = await client.post(
        f"/api/v1/questions/{question['id']}/resolve",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
            "answer_id": answer["id"],
        },
    )
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    assert resolved.json()["accepted_answer_id"] == answer["id"]

    detail = await client.get(
        f"/api/v1/questions/{question['id']}",
        params={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
        },
    )
    assert detail.status_code == 200
    assert detail.json()["accepted_answer"]["id"] == answer["id"]
    assert detail.json()["accepted_answer"]["is_accepted"] is True
    assert len(detail.json()["answers"]) == 1

    reopened = await client.post(
        f"/api/v1/questions/{question['id']}/reopen",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["admin_id"]),
        },
    )
    assert reopened.status_code == 200
    assert reopened.json()["status"] == "open"
    assert reopened.json()["accepted_answer_id"] is None
    assert reopened.json()["resolved_at"] is None


@pytest.mark.asyncio
async def test_comment_and_reaction_upsert(app_client) -> None:
    client, session_factory = app_client
    identities = await seed_users(session_factory)
    question = await create_question(client, identities)
    answer = await create_answer(client, identities, question["id"])

    comment = await client.post(
        f"/api/v1/questions/{question['id']}/comments",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "author_id": str(identities["author_id"]),
            "answer_id": answer["id"],
            "body": "Is manager approval required?",
        },
    )
    assert comment.status_code == 201
    assert comment.json()["author"]["display_name"] == "Question Author"

    reaction_url = f"/api/v1/answers/{answer['id']}/reaction"
    helpful = await client.post(
        reaction_url,
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
            "reaction": "helpful",
        },
    )
    assert helpful.json()["helpful_count"] == 1
    changed = await client.post(
        reaction_url,
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
            "reaction": "not_helpful",
        },
    )
    assert changed.json()["helpful_count"] == 0
    assert changed.json()["not_helpful_count"] == 1

    async with session_factory() as session:
        count = await session.scalar(select(func.count(AnswerReaction.id)))
        assert count == 1


@pytest.mark.asyncio
async def test_cross_organisation_access_is_hidden(app_client) -> None:
    client, session_factory = app_client
    identities = await seed_users(session_factory)
    question = await create_question(client, identities)
    answer = await create_answer(client, identities, question["id"])

    detail = await client.get(
        f"/api/v1/questions/{question['id']}",
        params={"organisation_id": str(identities["other_organisation_id"])},
    )
    assert detail.status_code == 404

    resolve = await client.post(
        f"/api/v1/questions/{question['id']}/resolve",
        json={
            "organisation_id": str(identities["other_organisation_id"]),
            "user_id": str(identities["outsider_id"]),
            "answer_id": answer["id"],
        },
    )
    assert resolve.status_code == 404


@pytest.mark.asyncio
async def test_update_archive_and_owned_content_crud(app_client) -> None:
    client, session_factory = app_client
    identities = await seed_users(session_factory)
    question = await create_question(client, identities)

    updated_question = await client.patch(
        f"/api/v1/questions/{question['id']}",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
            "title": "What is the mileage claim process?",
        },
    )
    assert updated_question.status_code == 200
    assert updated_question.json()["title"] == "What is the mileage claim process?"

    listed = await client.get(
        "/api/v1/questions",
        params={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["author_id"]),
            "status": "open",
        },
    )
    assert listed.status_code == 200
    assert listed.json()[0]["answer_count"] == 0

    answer = await create_answer(client, identities, question["id"])
    updated_answer = await client.patch(
        f"/api/v1/answers/{answer['id']}",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["contributor_id"]),
            "body": "Use the current Finance mileage form.",
        },
    )
    assert updated_answer.status_code == 200
    assert updated_answer.json()["author"]["display_name"] == "Contributor"

    comment = await client.post(
        f"/api/v1/questions/{question['id']}/comments",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "author_id": str(identities["contributor_id"]),
            "body": "The form changed this year.",
        },
    )
    comment_id = comment.json()["id"]
    updated_comment = await client.patch(
        f"/api/v1/comments/{comment_id}",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["contributor_id"]),
            "body": "The form changed recently.",
        },
    )
    assert updated_comment.status_code == 200
    assert updated_comment.json()["body"] == "The form changed recently."
    deleted_comment = await client.delete(
        f"/api/v1/comments/{comment_id}",
        params={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["contributor_id"]),
        },
    )
    assert deleted_comment.status_code == 204

    deleted_answer = await client.delete(
        f"/api/v1/answers/{answer['id']}",
        params={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["contributor_id"]),
        },
    )
    assert deleted_answer.status_code == 204

    archived = await client.post(
        f"/api/v1/questions/{question['id']}/archive",
        json={
            "organisation_id": str(identities["organisation_id"]),
            "user_id": str(identities["admin_id"]),
            "reason": "No longer current.",
        },
    )
    assert archived.status_code == 200
    assert archived.json()["status"] == "archived"