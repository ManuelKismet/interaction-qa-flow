import pytest
from sqlalchemy import select
from uuid import UUID

from app.models.organisation import Organisation
from app.models.question import Question, QuestionStatus
from app.models.user import User


@pytest.mark.asyncio
async def test_create_question_persists_tenant_owned_question(app_client) -> None:
    client, session_factory = app_client
    async with session_factory() as session:
        organisation = Organisation(name="Example Council", slug="example-council")
        session.add(organisation)
        await session.flush()
        author = User(
            organisation_id=organisation.id,
            email="employee@example.test",
            display_name="Example Employee",
        )
        session.add(author)
        await session.commit()

    response = await client.post(
        "/api/v1/questions",
        json={
            "organisation_id": str(organisation.id),
            "author_id": str(author.id),
            "title": "How do I claim mileage?",
            "visibility": "organisation",
        },
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["organisation_id"] == str(organisation.id)
    assert payload["status"] == "open"

    async with session_factory() as session:
        stored = await session.scalar(
            select(Question).where(Question.id == UUID(payload["id"]))
        )
        assert stored is not None
        assert stored.organisation_id == organisation.id
        assert stored.status == QuestionStatus.OPEN