import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import SQLAlchemyError

from app.ai.embedding_provider import (
    EmbeddingProvider,
    EmbeddingProviderError,
    get_embedding_provider,
)
from app.ai.embedding_service import EmbeddingService
from app.core.config import get_settings
from app.core.exceptions import ConflictError, NotFoundError
from app.models.question import Question, QuestionStatus
from app.repositories.answer import AnswerRepository
from app.repositories.department import DepartmentRepository
from app.repositories.question import QuestionRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.answer import AnswerDetailResponse
from app.schemas.canonical import CanonicalQuestionSummary, QuestionAliasSummary
from app.schemas.department import DepartmentSummary
from app.schemas.question import (
    QuestionAction,
    QuestionCreate,
    QuestionDetailResponse,
    QuestionListItem,
    QuestionResolve,
    QuestionUpdate,
)
from app.schemas.user import UserSummary
from app.schemas.team import TeamSummary
from app.services.freshness import answer_freshness
from app.services.permissions import PermissionService

logger = logging.getLogger(__name__)


class QuestionService:
    def __init__(
        self,
        session: AsyncSession,
        embedding_provider: EmbeddingProvider | None = None,
    ) -> None:
        self.session = session
        self.departments = DepartmentRepository(session)
        self.answers = AnswerRepository(session)
        self.questions = QuestionRepository(session)
        self.teams = TeamRepository(session)
        self.users = UserRepository(session)
        self.permissions = PermissionService(self.users)
        self.embedding_service = EmbeddingService(
            session,
            embedding_provider or get_embedding_provider(),
        )
        self.settings = get_settings()

    async def create(self, data: QuestionCreate) -> Question:
        if not await self.users.get_for_organisation(
            data.author_id,
            data.organisation_id,
        ):
            raise NotFoundError("Author not found in this organisation")

        department = None
        if data.department_id and not (department := await self.departments.get_for_organisation(
            data.department_id,
            data.organisation_id,
        )):
            raise NotFoundError("Department not found in this organisation")

        await self._validate_team(
            data.team_id, data.department_id, data.organisation_id
        )

        question = Question(**data.model_dump())
        await self.questions.add(question)
        await self.session.commit()
        await self.session.refresh(question)
        await self._sync_embedding_safely(question)
        return question

    async def list(
        self,
        organisation_id: UUID,
        user_id: UUID,
        offset: int,
        limit: int,
        status: QuestionStatus | None = None,
        department_id: UUID | None = None,
        team_id: UUID | None = None,
        author_id: UUID | None = None,
    ) -> list[QuestionListItem]:
        actor = await self.permissions.actor(user_id, organisation_id)
        rows = await self.questions.list_for_organisation(
            organisation_id,
            offset,
            limit,
            actor=actor,
            status=status,
            department_id=department_id,
            team_id=team_id,
            author_id=author_id,
        )
        return [
            QuestionListItem.model_validate(
                {
                    **question.__dict__,
                    "department": DepartmentSummary.model_validate(department)
                    if department
                    else None,
                    "team": TeamSummary.model_validate(team) if team else None,
                    "answer_count": answer_count,
                }
            )
            for question, department, team, answer_count in rows
        ]

    async def get(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> QuestionDetailResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        detail = await self.questions.get_detail_for_organisation(
            question_id,
            organisation_id,
        )
        if not detail:
            raise NotFoundError("Question not found")
        question, author, department, team = detail
        self.permissions.require_question_visibility(actor, question)
        canonical_question = None
        aliases = []
        if question.canonical_question_id:
            canonical = await self.questions.get_for_organisation(
                question.canonical_question_id, organisation_id
            )
            if canonical and self.permissions.can_view_question(actor, canonical):
                canonical_question = CanonicalQuestionSummary(
                    id=canonical.id, title=canonical.title
                )
        else:
            aliases = [
                QuestionAliasSummary.model_validate(alias)
                for alias in await self.questions.list_aliases(
                    question.id, organisation_id, limit=5, actor=actor
                )
            ]
        answer_rows = await self.answers.list_details_for_question(
            question_id,
            organisation_id,
        )
        answers = [
            AnswerDetailResponse.model_validate(
                {
                    **answer.__dict__,
                    "author": UserSummary.model_validate(answer_author),
                    "verified_by_user": UserSummary.model_validate(verifier)
                    if verifier
                    else None,
                    "helpful_count": helpful_count,
                    "not_helpful_count": not_helpful_count,
                    "is_accepted": answer.id == question.accepted_answer_id,
                    "freshness_status": answer_freshness(
                        answer,
                        has_open_challenge=challenge_count > 0,
                        due_soon_days=self.settings.review_due_soon_days,
                    ),
                    "challenge_count": challenge_count,
                    "has_open_challenge": challenge_count > 0,
                }
            )
            for answer, answer_author, verifier, helpful_count, not_helpful_count, challenge_count in answer_rows
        ]
        return QuestionDetailResponse.model_validate(
            {
                **question.__dict__,
                "author": UserSummary.model_validate(author),
                "department": DepartmentSummary.model_validate(department)
                if department
                else None,
                "team": TeamSummary.model_validate(team) if team else None,
                "answers": answers,
                "accepted_answer": next(
                    (answer for answer in answers if answer.is_accepted),
                    None,
                ),
                "comment_count": await self.questions.comment_count(
                    question_id,
                    organisation_id,
                ),
                "canonical_question": canonical_question,
                "aliases": aliases,
            }
        )

    async def update(self, question_id: UUID, data: QuestionUpdate) -> Question:
        question = await self._owned_question(question_id, data.organisation_id, data.user_id)
        changes = data.model_dump(
            exclude={"organisation_id", "user_id"},
            exclude_unset=True,
        )
        embedding_changed = any(
            field in changes and changes[field] != getattr(question, field)
            for field in ("title", "body")
        )
        if "department_id" in changes and changes["department_id"] is not None:
            if not await self.departments.get_for_organisation(
                changes["department_id"],
                data.organisation_id,
            ):
                raise NotFoundError("Department not found in this organisation")
        await self._validate_team(
            changes.get("team_id", question.team_id),
            changes.get("department_id", question.department_id),
            data.organisation_id,
        )
        for field, value in changes.items():
            setattr(question, field, value)
        await self.session.commit()
        await self.session.refresh(question)
        if embedding_changed:
            await self._sync_embedding_safely(question)
        return question

    async def _validate_team(
        self,
        team_id: UUID | None,
        department_id: UUID | None,
        organisation_id: UUID,
    ) -> None:
        if team_id is None:
            return
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found in this organisation")
        team, _ = row
        if (
            team.department_id is not None
            and department_id is not None
            and team.department_id != department_id
        ):
            raise ConflictError("Team does not belong to the selected department")

    async def resolve(self, question_id: UUID, data: QuestionResolve) -> Question:
        question = await self._owned_question(question_id, data.organisation_id, data.user_id)
        answer = await self.answers.get_for_organisation(
            data.answer_id,
            data.organisation_id,
        )
        if not answer or answer.question_id != question.id:
            raise NotFoundError("Answer not found for this question")
        question.accepted_answer_id = answer.id
        question.status = QuestionStatus.RESOLVED
        question.resolved_at = datetime.now(UTC)
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def reopen(self, question_id: UUID, data: QuestionAction) -> Question:
        question = await self._owned_question(question_id, data.organisation_id, data.user_id)
        if question.status != QuestionStatus.RESOLVED:
            raise ConflictError("Only resolved questions can be reopened")
        question.status = QuestionStatus.OPEN
        question.accepted_answer_id = None
        question.resolved_at = None
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def archive(self, question_id: UUID, data: QuestionAction) -> Question:
        question = await self._owned_question(question_id, data.organisation_id, data.user_id)
        question.status = QuestionStatus.ARCHIVED
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def _owned_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> Question:
        question = await self.questions.get_for_organisation(question_id, organisation_id)
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        self.permissions.require_question_owner_or_admin(actor, question)
        return question

    async def _sync_embedding_safely(self, question: Question) -> None:
        question_id = question.id
        try:
            await self.embedding_service.sync_question(question)
        except (EmbeddingProviderError, SQLAlchemyError, ValueError):
            await self.session.rollback()
            await self.session.refresh(question)
            logger.exception("Failed to generate embedding for question %s", question_id)