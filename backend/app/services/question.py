from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import SQLAlchemyError

from app.ai.embedding_provider import (
    EmbeddingProvider,
    EmbeddingProviderError,
    get_embedding_provider,
)
from app.ai.embedding_service import EmbeddingService
from app.core.config import get_settings
from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.models.answer import Answer, AnswerStatus
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditAction, AuditEvent
from app.models.question_change_request import (
    ChangeRequestStatus,
    QuestionChangeRequest,
)
from app.models.question import Question, QuestionStatus
from app.models.question_version import QuestionVersion
from app.models.user import User, UserRole
from app.repositories.answer import AnswerRepository
from app.repositories.department import DepartmentRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.question import QuestionRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.answer import AnswerDetailResponse
from app.schemas.canonical import CanonicalQuestionSummary, QuestionAliasSummary
from app.schemas.department import DepartmentSummary
from app.schemas.question import (
    ArchiveQuestionRequest,
    ChangeRequestDecision,
    QuestionAction,
    QuestionChangeRequestCreate,
    QuestionChangeRequestResponse,
    QuestionChangeRequestReview,
    QuestionCreate,
    QuestionDetailResponse,
    QuestionListItem,
    QuestionResolve,
    QuestionVersionResponse,
    RestoreQuestionRequest,
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
        self.governance = GovernanceRepository(session)
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
            canonical = await self._visible_canonical_question(
                question, organisation_id, actor
            )
            if canonical:
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

    async def _visible_canonical_question(
        self, question: Question, organisation_id: UUID, actor: User
    ) -> Question | None:
        immediate = None
        seen = {question.id}
        current = question
        while current.canonical_question_id is not None:
            canonical_id = current.canonical_question_id
            if canonical_id in seen:
                return None
            canonical = await self.questions.get_for_organisation(
                canonical_id, organisation_id
            )
            if not canonical or not self.permissions.can_view_question(
                actor, canonical
            ):
                return None
            if immediate is None:
                immediate = canonical
            seen.add(canonical.id)
            current = canonical
        return immediate

    async def update(self, question_id: UUID, data: QuestionUpdate) -> Question:
        question, actor = await self._question_and_actor(
            question_id, data.organisation_id, data.user_id
        )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions must be restored before editing")
        protected = await self._is_protected(question)
        has_contributions = await self._has_contributions(question)
        changes = data.model_dump(
            exclude={"organisation_id", "user_id", "reason"},
            exclude_unset=True,
        )
        changes = {
            field: value
            for field, value in changes.items()
            if value != getattr(question, field)
        }
        if not changes:
            return question
        if (protected or has_contributions) and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError(
                "Only an administrator can edit a contributed question"
            )
        reason = (data.reason or "").strip()
        if (protected or has_contributions) and not reason:
            raise ConflictError("A reason is required for administrator edits")
        if protected or has_contributions:
            await self._create_question_version(question, actor, reason)
            await self._audit(
                actor,
                AuditAction.QUESTION_VERSION_CREATED,
                "question",
                question.id,
                {"reason": reason},
            )
        if protected:
            await self._invalidate_question_approval(question, actor, reason)
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
        question, actor = await self._question_and_actor(
            question_id, data.organisation_id, data.user_id
        )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions must be restored before resolving")
        if await self._is_protected(question) and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError(
                "Only an administrator can change an approved question"
            )
        answer = await self.answers.get_for_organisation(
            data.answer_id,
            data.organisation_id,
        )
        if not answer or answer.question_id != question.id:
            raise NotFoundError("Answer not found for this question")
        question.accepted_answer_id = answer.id
        question.status = QuestionStatus.RESOLVED
        question.resolved_at = datetime.now(UTC)
        question.protected_at = question.protected_at or question.resolved_at
        answer.protected_at = answer.protected_at or question.resolved_at
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def reopen(self, question_id: UUID, data: QuestionAction) -> Question:
        question, actor = await self._question_and_actor(
            question_id, data.organisation_id, data.user_id
        )
        if await self._is_protected(question) and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError(
                "Only an administrator can reopen approved knowledge"
            )
        if question.status != QuestionStatus.RESOLVED:
            raise ConflictError("Only resolved questions can be reopened")
        question.status = QuestionStatus.OPEN
        question.accepted_answer_id = None
        question.resolved_at = None
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def archive(
        self, question_id: UUID, data: ArchiveQuestionRequest
    ) -> Question:
        question, actor = await self._question_and_actor(
            question_id, data.organisation_id, data.user_id
        )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Question is already archived")
        if (
            await self._is_protected(question)
            or await self._has_contributions(question)
        ) and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError(
                "Only an administrator can archive a contributed question"
            )
        reason = data.reason.strip()
        if not reason:
            raise ConflictError("An archive reason is required")
        await self._create_question_version(question, actor, reason)
        question.status_before_archive = question.status
        question.status = QuestionStatus.ARCHIVED
        question.archived_at = datetime.now(UTC)
        question.archived_by = actor.id
        question.archive_reason = reason
        await self._audit(
            actor,
            AuditAction.QUESTION_ARCHIVED,
            "question",
            question.id,
            {"reason": reason},
        )
        await self._audit(
            actor,
            AuditAction.QUESTION_VERSION_CREATED,
            "question",
            question.id,
            {"reason": reason},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def restore(
        self, question_id: UUID, data: RestoreQuestionRequest
    ) -> Question:
        question, actor = await self._question_and_actor(
            question_id, data.organisation_id, data.user_id
        )
        if question.status != QuestionStatus.ARCHIVED:
            raise ConflictError("Only archived questions can be restored")
        if (
            await self._is_protected(question)
            or await self._has_contributions(question)
        ) and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError(
                "Only an administrator can restore a contributed question"
            )
        reason = data.reason.strip()
        if not reason:
            raise ConflictError("A restoration reason is required")
        question.status = question.status_before_archive or QuestionStatus.OPEN
        question.status_before_archive = None
        question.archived_at = None
        question.archived_by = None
        question.archive_reason = None
        await self._create_question_version(question, actor, reason)
        await self._audit(
            actor,
            AuditAction.QUESTION_RESTORED,
            "question",
            question.id,
            {"reason": reason},
        )
        await self._audit(
            actor,
            AuditAction.QUESTION_VERSION_CREATED,
            "question",
            question.id,
            {"reason": reason},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return question

    async def request_change(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: QuestionChangeRequestCreate,
    ) -> QuestionChangeRequestResponse:
        question = await self.questions.get_for_organisation(
            question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        if actor.id != question.author_id:
            raise PermissionDeniedError(
                "Only the question author can request a change review"
            )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions cannot receive change requests")
        if not await self._has_contributions(question):
            raise ConflictError(
                "Questions without contributions can be edited directly"
            )
        change_title = "title" in data.model_fields_set and data.title is not None
        change_body = "body" in data.model_fields_set
        if not (change_title or change_body or data.archive):
            raise ConflictError("A change request must propose an edit or archival")
        reason = data.reason.strip()
        if not reason:
            raise ConflictError("A change request reason is required")

        request = QuestionChangeRequest(
            organisation_id=organisation_id,
            question_id=question.id,
            requested_by=actor.id,
            proposed_title=data.title,
            proposed_body=data.body,
            change_title=change_title,
            change_body=change_body,
            archive_requested=data.archive,
            reason=reason,
        )
        await self.questions.add_change_request(request)
        await self._audit(
            actor,
            AuditAction.QUESTION_CHANGE_REQUESTED,
            "question_change_request",
            request.id,
            {"question_id": str(question.id)},
        )
        await self.session.commit()
        await self.session.refresh(request)
        return QuestionChangeRequestResponse.model_validate(request)

    async def list_change_requests(
        self,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[QuestionChangeRequestResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_admin(actor)
        rows = await self.questions.list_change_requests(
            organisation_id, actor
        )
        return [
            QuestionChangeRequestResponse.model_validate(request)
            for request, _, _ in rows
        ]

    async def review_change_request(
        self,
        request_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: QuestionChangeRequestReview,
    ) -> QuestionChangeRequestResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_admin(actor)
        row = await self.questions.get_change_request(
            request_id, organisation_id
        )
        if not row:
            raise NotFoundError("Change request not found")
        request, question = row
        self.permissions.require_question_visibility(actor, question)
        if request.status != ChangeRequestStatus.PENDING:
            raise ConflictError("Change request has already been reviewed")
        review_note = (data.review_note or "").strip() or request.reason
        if data.decision == ChangeRequestDecision.APPROVE:
            if request.archive_requested:
                await self.archive(
                    question.id,
                    ArchiveQuestionRequest(
                        organisation_id=organisation_id,
                        user_id=user_id,
                        reason=review_note,
                    ),
                )
            else:
                update_values = {
                    "organisation_id": organisation_id,
                    "user_id": user_id,
                    "reason": review_note,
                }
                if request.change_title:
                    update_values["title"] = request.proposed_title
                if request.change_body:
                    update_values["body"] = request.proposed_body
                await self.update(
                    question.id,
                    QuestionUpdate.model_validate(update_values),
                )
            request.status = ChangeRequestStatus.APPROVED
        else:
            request.status = ChangeRequestStatus.REJECTED
        request.reviewed_by = actor.id
        request.reviewed_at = datetime.now(UTC)
        request.review_note = review_note
        await self._audit(
            actor,
            AuditAction.QUESTION_CHANGE_REQUEST_REVIEWED,
            "question_change_request",
            request.id,
            {"decision": data.decision.value, "question_id": str(question.id)},
        )
        await self.session.commit()
        await self.session.refresh(request)
        return QuestionChangeRequestResponse.model_validate(request)

    async def list_versions(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[QuestionVersionResponse]:
        question = await self.questions.get_for_organisation(
            question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        return [
            QuestionVersionResponse.model_validate(
                {
                    **version.__dict__,
                    "changed_by": UserSummary.model_validate(changed_by),
                }
            )
            for version, changed_by in await self.questions.list_versions(
                question_id, organisation_id, actor
            )
        ]

    async def _is_protected(self, question: Question) -> bool:
        return bool(
            question.protected_at
            or question.accepted_answer_id
            or await self.questions.has_verified_answer(
                question.id, question.organisation_id
            )
        )

    async def _has_contributions(self, question: Question) -> bool:
        return bool(question.contribution_started_at) or (
            await self.questions.contribution_count(
                question.id, question.organisation_id
            )
        ) > 0

    async def _create_question_version(
        self,
        question: Question,
        actor: User,
        reason: str,
    ) -> QuestionVersion:
        version = QuestionVersion(
            organisation_id=question.organisation_id,
            question_id=question.id,
            version_number=await self.questions.next_version_number(
                question.id, question.organisation_id
            ),
            title=question.title,
            body=question.body,
            status_snapshot=question.status,
            visibility_snapshot=question.visibility,
            department_id=question.department_id,
            team_id=question.team_id,
            changed_by=actor.id,
            change_reason=reason,
        )
        self.session.add(version)
        await self.session.flush()
        return version

    async def _invalidate_question_approval(
        self,
        question: Question,
        actor: User,
        reason: str,
    ) -> None:
        approved_answers = list(
            await self.session.scalars(
                select(Answer).where(
                    Answer.question_id == question.id,
                    Answer.organisation_id == question.organisation_id,
                    Answer.archived_at.is_(None),
                    (
                        (Answer.status == AnswerStatus.VERIFIED)
                        | (Answer.id == question.accepted_answer_id)
                    ),
                )
            )
        )
        for answer in approved_answers:
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
            await self._audit(
                actor,
                AuditAction.ANSWER_VERSION_CREATED,
                "answer_version",
                version.id,
                {"answer_id": str(answer.id), "reason": reason},
            )
            answer.status = AnswerStatus.COMMUNITY
            answer.verified_by = None
            answer.verified_at = None
            answer.review_due_at = None
            answer.last_reviewed_at = None
            answer.last_reviewed_by = None
        question.accepted_answer_id = None
        question.status = QuestionStatus.UNDER_REVIEW
        question.resolved_at = None

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

    async def _owned_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> Question:
        question, _ = await self._question_and_actor(
            question_id, organisation_id, user_id
        )
        return question

    async def _question_and_actor(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> tuple[Question, User]:
        question = await self.questions.get_for_organisation(
            question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        self.permissions.require_question_owner_or_admin(actor, question)
        return question, actor

    async def _sync_embedding_safely(self, question: Question) -> None:
        question_id = question.id
        try:
            await self.embedding_service.sync_question(question)
        except (EmbeddingProviderError, ValueError):
            logger.exception(
                "Failed to generate embedding for question %s", question_id
            )
        except SQLAlchemyError:
            await self.session.rollback()
            await self.session.refresh(question)
            logger.exception("Failed to generate embedding for question %s", question_id)