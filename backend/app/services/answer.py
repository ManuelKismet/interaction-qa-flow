import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProviderError, get_embedding_provider
from app.ai.embedding_service import EmbeddingService
from app.core.config import get_settings
from app.core.exceptions import (
    ConflictError,
    NotFoundError,
)
from app.models.answer import Answer, AnswerStatus
from app.models.answer_reaction import AnswerReaction
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditAction, AuditEvent
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.repositories.answer import AnswerReactionRepository, AnswerRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.question import QuestionRepository
from app.repositories.user import UserRepository
from app.schemas.answer import (
    AnswerCreate,
    AnswerDetailResponse,
    AnswerRestoreRequest,
    AnswerUpdate,
    ReactionCreate,
    ReactionResponse,
)
from app.schemas.user import UserSummary
from app.services.freshness import answer_freshness
from app.services.permissions import PermissionService

logger = logging.getLogger(__name__)


class AnswerService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.answers = AnswerRepository(session)
        self.reactions = AnswerReactionRepository(session)
        self.questions = QuestionRepository(session)
        self.users = UserRepository(session)
        self.governance = GovernanceRepository(session)
        self.permissions = PermissionService(self.users)
        self.settings = get_settings()
        self.embedding_service = EmbeddingService(
            session, get_embedding_provider(self.settings)
        )

    async def create(
        self,
        question_id: UUID,
        data: AnswerCreate,
        *,
        commit: bool = True,
    ) -> AnswerDetailResponse:
        question, _ = await self._visible_question(
            question_id, data.organisation_id, data.author_id
        )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions cannot receive new answers")

        answer = Answer(
            question_id=question_id,
            status=AnswerStatus.COMMUNITY,
            **data.model_dump(),
        )
        await self.answers.add(answer)
        question.contribution_started_at = (
            question.contribution_started_at or datetime.now(UTC)
        )
        if question.status == QuestionStatus.OPEN:
            question.status = QuestionStatus.ANSWERED
        if commit:
            await self.session.commit()
            await self.session.refresh(answer)
            await self._sync_question_embedding(question)
        else:
            await self.session.flush()
        return await self._detail(answer)

    async def list(
        self, question_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> list[AnswerDetailResponse]:
        question, _ = await self._visible_question(
            question_id, organisation_id, user_id
        )
        rows = await self.answers.list_details_for_question(question_id, organisation_id)
        return [
            AnswerDetailResponse.model_validate(
                {
                    **answer.__dict__,
                    "author": UserSummary.model_validate(author),
                    "verified_by_user": UserSummary.model_validate(verifier)
                    if verifier
                    else None,
                    "helpful_count": helpful,
                    "not_helpful_count": not_helpful,
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
            for answer, author, verifier, helpful, not_helpful, challenge_count in rows
        ]

    async def update(self, answer_id: UUID, data: AnswerUpdate) -> AnswerDetailResponse:
        answer, question, actor = await self._answer_and_actor(
            answer_id, data.organisation_id, data.user_id
        )
        if answer.archived_at is not None:
            raise ConflictError("Archived answers must be restored before editing")
        protected = self._is_protected_answer(answer, question)
        if protected:
            await self.permissions.require_permission(
                actor,
                "answer_approval",
                department_id=question.department_id,
                team_id=question.team_id,
            )
            reason = (data.reason or "").strip()
            if not reason:
                raise ConflictError(
                    "A reason is required when an administrator edits an approved answer"
                )
            await self._create_version(answer, actor, reason)
            self._demote_approved_answer(answer, question)
            await self._audit(
                actor,
                AuditAction.ANSWER_VERSION_CREATED,
                "answer",
                answer.id,
                {"reason": reason},
            )
            await self._audit(
                actor,
                AuditAction.ANSWER_UNVERIFIED,
                "answer",
                answer.id,
                {"reason": reason},
            )
        else:
            self.permissions.require_owner(actor, answer.author_id)
        answer.body = data.body
        await self.session.commit()
        await self.session.refresh(answer)
        await self._sync_question_embedding(question)
        return await self._detail(answer)

    async def delete(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        reason: str | None = None,
    ) -> None:
        answer, question, actor = await self._answer_and_actor(
            answer_id, organisation_id, user_id
        )
        if answer.archived_at is not None:
            raise ConflictError("Answer is already archived")
        if self._is_protected_answer(answer, question):
            await self.permissions.require_permission(
                actor,
                "answer_approval",
                department_id=question.department_id,
                team_id=question.team_id,
            )
            archive_reason = (reason or "").strip()
            if not archive_reason:
                raise ConflictError(
                    "A reason is required when an administrator removes an approved answer"
                )
            await self._create_version(answer, actor, archive_reason)
            self._demote_approved_answer(answer, question)
            answer.archived_at = datetime.now(UTC)
            answer.archived_by = actor.id
            answer.archive_reason = archive_reason
            await self._audit(
                actor,
                AuditAction.ANSWER_ARCHIVED,
                "answer",
                answer.id,
                {"reason": archive_reason},
            )
            await self._audit(
                actor,
                AuditAction.ANSWER_VERSION_CREATED,
                "answer",
                answer.id,
                {"reason": archive_reason},
            )
            await self.session.commit()
            await self._sync_question_embedding(question)
            return
        self.permissions.require_owner(actor, answer.author_id)
        await self.answers.delete(answer)
        await self.session.commit()
        await self._sync_question_embedding(question)

    async def restore(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: AnswerRestoreRequest,
    ) -> AnswerDetailResponse:
        answer, question, actor = await self._answer_and_actor(
            answer_id, organisation_id, user_id
        )
        await self.permissions.require_admin(actor)
        if answer.archived_at is None:
            raise ConflictError("Only archived answers can be restored")
        answer.archived_at = None
        answer.archived_by = None
        answer.archive_reason = None
        answer.status = AnswerStatus.COMMUNITY
        question.status = QuestionStatus.UNDER_REVIEW
        question.accepted_answer_id = None
        question.resolved_at = None
        await self._audit(
            actor,
            AuditAction.ANSWER_RESTORED,
            "answer",
            answer.id,
            {"reason": data.reason.strip()},
        )
        await self.session.commit()
        await self.session.refresh(answer)
        await self._sync_question_embedding(question)
        return await self._detail(answer)

    async def react(self, answer_id: UUID, data: ReactionCreate) -> ReactionResponse:
        answer = await self.answers.get_for_organisation(answer_id, data.organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        await self._visible_question(
            answer.question_id, data.organisation_id, data.user_id
        )
        reaction = await self.reactions.get(answer_id, data.user_id, data.organisation_id)
        if reaction:
            reaction.reaction = data.reaction
        else:
            reaction = AnswerReaction(
                organisation_id=data.organisation_id,
                answer_id=answer_id,
                user_id=data.user_id,
                reaction=data.reaction,
            )
            await self.reactions.add(reaction)
        await self.session.commit()
        helpful, not_helpful = await self.reactions.counts(answer_id, data.organisation_id)
        return ReactionResponse(
            answer_id=answer_id,
            reaction=reaction.reaction,
            helpful_count=helpful,
            not_helpful_count=not_helpful,
        )

    async def _answer_and_actor(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> tuple[Answer, Question, User]:
        answer = await self.answers.get_for_organisation(answer_id, organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        question, actor = await self._visible_question(
            answer.question_id, organisation_id, user_id
        )
        return answer, question, actor

    @staticmethod
    def _is_protected_answer(answer: Answer, question: Question) -> bool:
        return bool(
            answer.protected_at
            or answer.status == AnswerStatus.VERIFIED
            or question.accepted_answer_id == answer.id
        )

    @staticmethod
    def _demote_approved_answer(answer: Answer, question: Question) -> None:
        answer.status = AnswerStatus.COMMUNITY
        answer.verified_by = None
        answer.verified_at = None
        answer.review_due_at = None
        answer.last_reviewed_at = None
        answer.last_reviewed_by = None
        question.accepted_answer_id = None
        question.status = QuestionStatus.UNDER_REVIEW
        question.resolved_at = None

    async def _create_version(
        self,
        answer: Answer,
        actor: User,
        reason: str,
    ) -> AnswerVersion:
        version = AnswerVersion(
            organisation_id=answer.organisation_id,
            question_id=answer.question_id,
            answer_id=answer.id,
            version_number=await self.governance.next_version_number(
                answer.question_id, answer.organisation_id
            ),
            body=answer.body,
            status_snapshot=answer.status,
            changed_by=actor.id,
            change_reason=reason,
        )
        await self.governance.add(version)
        return version

    async def _audit(
        self,
        actor: User,
        action: AuditAction,
        entity_type: str,
        entity_id: UUID,
        metadata: dict | None = None,
    ) -> None:
        await self.governance.add(
            AuditEvent(
                organisation_id=actor.organisation_id,
                actor_id=actor.id,
                action=action.value,
                entity_type=entity_type,
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )

    async def _visible_question(
        self, question_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> tuple[Question, User]:
        question = await self.questions.get_for_organisation(
            question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_question_visibility(actor, question)
        return question, actor

    async def _sync_question_embedding(self, question: Question) -> None:
        try:
            await self.embedding_service.sync_question(question)
        except (EmbeddingProviderError, ValueError):
            logger.exception(
                "Failed to regenerate search embedding for question %s",
                question.id,
            )
        except SQLAlchemyError:
            await self.session.rollback()
            await self.session.refresh(question)
            logger.exception(
                "Failed to persist search embedding for question %s",
                question.id,
            )

    async def _detail(self, answer: Answer) -> AnswerDetailResponse:
        question = await self.questions.get_for_organisation(
            answer.question_id,
            answer.organisation_id,
        )
        rows = await self.answers.list_details_for_question(
            answer.question_id,
            answer.organisation_id,
        )
        for row_answer, author, verifier, helpful, not_helpful, challenge_count in rows:
            if row_answer.id == answer.id:
                return AnswerDetailResponse.model_validate(
                    {
                        **row_answer.__dict__,
                        "author": UserSummary.model_validate(author),
                        "verified_by_user": UserSummary.model_validate(verifier)
                        if verifier
                        else None,
                        "helpful_count": helpful,
                        "not_helpful_count": not_helpful,
                        "is_accepted": bool(
                            question and question.accepted_answer_id == answer.id
                        ),
                        "freshness_status": answer_freshness(
                            row_answer,
                            has_open_challenge=challenge_count > 0,
                            due_soon_days=self.settings.review_due_soon_days,
                        ),
                        "challenge_count": challenge_count,
                        "has_open_challenge": challenge_count > 0,
                    }
                )
        raise NotFoundError("Answer not found")