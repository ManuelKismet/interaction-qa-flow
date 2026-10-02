import pytest

from app.ai.embedding_provider import DeterministicFakeEmbeddingProvider, EmbeddingProviderError
from app.core.config import Settings
from app.models.answer import Answer, AnswerStatus
from app.models.department import Department
from app.models.organisation import Organisation
from app.models.question import Question, QuestionStatus, QuestionVisibility
from app.models.user import User, UserRole
from app.services.search import SearchService


class FailedEmbeddingProvider(DeterministicFakeEmbeddingProvider):
    async def embed_text(self, text: str) -> list[float]:
        raise EmbeddingProviderError("synthetic provider failure")


SYNTHETIC_QUERIES = [
    ("password", "password"),
    ("pass", "password"),
    ("PASS!", "password"),
    ("reset", "password"),
    ("reset password", "password"),
    ("password reset", "password"),
    ("How do I reset my password?", "password"),
    ("account password", "password"),
    ("forgot password", "password"),
    ("recover password", "password"),
    ("recover login", "password"),
    ("login reset", "password"),
    ("SSO-2FA-token", "sso"),
    ("sso", "sso"),
    ("token", "sso"),
    ("2fa token", "sso"),
    ("SSO 2FA", "sso"),
    ("annual leave", "leave"),
    ("holiday booking", "leave"),
    ("vacation", "leave"),
    ("time off", "leave"),
    ("How to book annual leave?", "leave"),
    ("mileage claim", "mileage"),
    ("expenses", "mileage"),
    ("reimbursement", "mileage"),
    ("mileage form", "mileage"),
    ("office lunch menu", None),
    ("weather tomorrow", None),
    ("confidential phrase", None),
    ("shared rumor", None),
    ("other tenant plan", None),
]


@pytest.mark.asyncio
async def test_labeled_synthetic_short_query_evaluation(app_client) -> None:
    _, session_factory = app_client
    async with session_factory() as session:
        organisation = Organisation(name="Synthetic Search", slug="synthetic-search")
        foreign_organisation = Organisation(
            name="Foreign Search", slug="foreign-search"
        )
        session.add_all([organisation, foreign_organisation])
        await session.flush()
        department = Department(
            organisation_id=organisation.id,
            name="Synthetic Department",
        )
        session.add(department)
        await session.flush()
        actor = User(
            organisation_id=organisation.id,
            email="synthetic@example.test",
            display_name="Synthetic Searcher",
            role=UserRole.EMPLOYEE,
        )
        department_user = User(
            organisation_id=organisation.id,
            department_id=department.id,
            email="department-searcher@example.test",
            display_name="Department Searcher",
            role=UserRole.EMPLOYEE,
        )
        admin = User(
            organisation_id=organisation.id,
            email="admin-searcher@example.test",
            display_name="Admin Searcher",
            role=UserRole.ADMIN,
        )
        private_owner = User(
            organisation_id=organisation.id,
            email="private-owner@example.test",
            display_name="Private Owner",
        )
        foreign_user = User(
            organisation_id=foreign_organisation.id,
            email="foreign@example.test",
            display_name="Foreign Searcher",
        )
        session.add_all([actor, department_user, admin, private_owner, foreign_user])
        await session.flush()

        questions = {
            "password": Question(
                organisation_id=organisation.id,
                author_id=actor.id,
                title="How do I reset my password?",
                body="Account password reset help if you forgot your password.",
                status=QuestionStatus.ANSWERED,
            ),
            "sso": Question(
                organisation_id=organisation.id,
                author_id=actor.id,
                title="Where is the SSO-2FA-token?",
                body="Find the single sign-on two-factor token.",
                status=QuestionStatus.ANSWERED,
            ),
            "leave": Question(
                organisation_id=organisation.id,
                author_id=actor.id,
                title="How to book annual leave?",
                body="Holiday and vacation booking; request time off.",
                status=QuestionStatus.ANSWERED,
            ),
            "mileage": Question(
                organisation_id=organisation.id,
                author_id=actor.id,
                title="How do I submit a mileage claim?",
                body="Expenses reimbursement uses the mileage form.",
                status=QuestionStatus.ANSWERED,
            ),
            "private": Question(
                organisation_id=organisation.id,
                author_id=private_owner.id,
                title="Confidential phrase",
                body="Private account recovery details.",
                status=QuestionStatus.ANSWERED,
                visibility=QuestionVisibility.PRIVATE,
            ),
            "private_canonical": Question(
                organisation_id=organisation.id,
                author_id=private_owner.id,
                title="Restricted canonical material",
                status=QuestionStatus.ANSWERED,
                visibility=QuestionVisibility.PRIVATE,
            ),
            "foreign": Question(
                organisation_id=foreign_organisation.id,
                author_id=foreign_user.id,
                title="Other tenant plan",
                status=QuestionStatus.ANSWERED,
            ),
            "archived": Question(
                organisation_id=organisation.id,
                author_id=actor.id,
                title="Retired manual",
                body="Archive-only content.",
                status=QuestionStatus.ARCHIVED,
            ),
            "department": Question(
                organisation_id=organisation.id,
                author_id=department_user.id,
                department_id=department.id,
                title="Department-only procedure",
                status=QuestionStatus.ANSWERED,
                visibility=QuestionVisibility.DEPARTMENT,
            ),
        }
        session.add_all(questions.values())
        await session.flush()

        password_alias = Question(
            organisation_id=organisation.id,
            author_id=actor.id,
            title="Recover account access",
            body="Login password recovery.",
            status=QuestionStatus.ANSWERED,
            canonical_question_id=questions["password"].id,
        )
        private_alias = Question(
            organisation_id=organisation.id,
            author_id=private_owner.id,
            title="Confidential phrase",
            status=QuestionStatus.ANSWERED,
            visibility=QuestionVisibility.PRIVATE,
            canonical_question_id=questions["leave"].id,
        )
        alias_to_private = Question(
            organisation_id=organisation.id,
            author_id=actor.id,
            title="Shared rumor",
            status=QuestionStatus.ANSWERED,
            canonical_question_id=questions["private_canonical"].id,
        )
        session.add_all([password_alias, private_alias, alias_to_private])
        await session.flush()

        for question in [*questions.values(), password_alias, private_alias, alias_to_private]:
            session.add(
                Answer(
                    organisation_id=question.organisation_id,
                    question_id=question.id,
                    author_id=question.author_id,
                    body="Synthetic answer.",
                    status=AnswerStatus.COMMUNITY,
                )
            )
        await session.commit()

        service = SearchService(session, FailedEmbeddingProvider(), Settings())
        permitted_ids = {
            key: questions[key].id
            for key in ("password", "sso", "leave", "mileage")
        }
        outcomes = []
        for query, expected_key in SYNTHETIC_QUERIES:
            results = await service.search(
                organisation_id=organisation.id,
                limit=10,
                query=query,
                user_id=actor.id,
            )
            canonical_ids = [result.question_id for result in results]
            expected_id = permitted_ids[expected_key] if expected_key else None
            outcomes.append((query, expected_id, set(canonical_ids)))
            if expected_id is None:
                assert not canonical_ids, f"Unexpected results for {query!r}: {canonical_ids}"
            else:
                assert expected_id in canonical_ids, (
                    f"{query!r} did not retrieve expected canonical {expected_id}"
                )
            assert len(canonical_ids) == len(set(canonical_ids)), (
                f"Canonical aliases were not collapsed for {query!r}"
            )
            assert all(result.confidence == "low_confidence" for result in results)

        assert len(outcomes) >= 30
        assert not await service.search(
            organisation_id=organisation.id,
            user_id=actor.id,
            query="archive-only",
            limit=5,
        )
        assert not await service.search(
            organisation_id=organisation.id,
            user_id=actor.id,
            query="department-only",
            limit=5,
        )
        department_results = await service.search(
            organisation_id=organisation.id,
            user_id=department_user.id,
            query="department-only",
            limit=5,
        )
        assert [result.question_id for result in department_results] == [
            questions["department"].id
        ]
        assert not await service.search(
            organisation_id=organisation.id,
            user_id=admin.id,
            query="confidential phrase",
            limit=5,
        )
