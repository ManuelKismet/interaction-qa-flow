import logging
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import (
    EmbeddingProviderError,
    get_embedding_provider,
)
from app.ai.embedding_service import EmbeddingService
from app.core.config import Settings
from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.models.answer import Answer, AnswerStatus
from app.models.answer_challenge import AnswerChallenge, ChallengeStatus
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditAction, AuditEvent
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.duplicate_suggestion import DuplicateSuggestionStatus
from app.models.question import Question, QuestionStatus
from app.models.user import User, UserRole
from app.repositories.answer import AnswerRepository
from app.repositories.canonical import CanonicalRepository
from app.repositories.department import DepartmentRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.question import QuestionRepository
from app.repositories.user import UserRepository
from app.schemas.department import DepartmentSummary
from app.schemas.governance import (
    AnswerChallengeResponse,
    AnswerVersionResponse,
    AuditEventResponse,
    ChallengeCreate,
    ChallengeDecision,
    DepartmentAnswerOwnerResponse,
    ReviewAnswerRequest,
    ReviewQueueItem,
    ReviewQueueType,
    VerifyAnswerRequest,
)
from app.schemas.user import UserSummary
from app.services.permissions import PermissionService

logger = logging.getLogger(__name__)


class GovernanceService:
    def __init__(self, session: AsyncSession, settings: Settings) -> None:
        self.session = session
        self.settings = settings
        self.answers = AnswerRepository(session)
        self.canonical = CanonicalRepository(session)
        self.departments = DepartmentRepository(session)
        self.governance = GovernanceRepository(session)
        self.questions = QuestionRepository(session)
        self.users = UserRepository(session)
        self.permissions = PermissionService(self.users)

    async def verify(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: VerifyAnswerRequest,
    ) -> Answer:
        answer, question, actor = await self._managed_answer(
            answer_id, organisation_id, user_id
        )
        if answer.status == AnswerStatus.VERIFIED:
            raise ConflictError("This answer is already verified")
        await self._supersede_current(question, answer.id, actor)
        now = datetime.now(UTC)
        answer.status = AnswerStatus.VERIFIED
        answer.protected_at = answer.protected_at or now
        question.protected_at = question.protected_at or now
        answer.verified_by = actor.id
        answer.verified_at = now
        answer.last_reviewed_by = actor.id
        answer.last_reviewed_at = now
        answer.review_due_at = now + timedelta(
            days=data.review_days or self.settings.default_review_days
        )
        if data.make_accepted:
            question.accepted_answer_id = answer.id
            question.status = QuestionStatus.RESOLVED
            question.resolved_at = now
        await self._create_version(answer, actor, "Answer verified")
        await self._audit(actor, AuditAction.ANSWER_VERIFIED, "answer", answer.id)
        await self.session.commit()
        await self.session.refresh(answer)
        await self._sync_question_embedding(question)
        return answer

    async def unverify(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> Answer:
        answer, question, actor = await self._managed_answer(
            answer_id, organisation_id, user_id
        )
        if answer.status != AnswerStatus.VERIFIED:
            raise ConflictError("Only a verified answer can be unverified")
        answer.status = AnswerStatus.COMMUNITY
        answer.verified_by = None
        answer.verified_at = None
        answer.review_due_at = None
        answer.last_reviewed_at = None
        answer.last_reviewed_by = None
        await self._audit(actor, AuditAction.ANSWER_UNVERIFIED, "answer", answer.id)
        await self.session.commit()
        await self.session.refresh(answer)
        await self._sync_question_embedding(question)
        return answer

    async def review(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: ReviewAnswerRequest,
    ) -> Answer:
        answer, _, actor = await self._managed_answer(
            answer_id, organisation_id, user_id, permission="review"
        )
        if answer.status != AnswerStatus.VERIFIED:
            raise ConflictError("Only verified answers can be reviewed")
        now = datetime.now(UTC)
        answer.last_reviewed_at = now
        answer.last_reviewed_by = actor.id
        answer.review_due_at = now + timedelta(
            days=data.review_days or self.settings.default_review_days
        )
        await self._audit(actor, AuditAction.ANSWER_REVIEWED, "answer", answer.id)
        await self.session.commit()
        await self.session.refresh(answer)
        return answer

    async def create_challenge(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: ChallengeCreate,
    ) -> AnswerChallengeResponse:
        answer, question, actor = await self._visible_answer(
            answer_id, organisation_id, user_id
        )
        challenge = AnswerChallenge(
            organisation_id=organisation_id,
            answer_id=answer.id,
            submitted_by=actor.id,
            **data.model_dump(),
        )
        await self.governance.add(challenge)
        await self._audit(
            actor,
            AuditAction.ANSWER_CHALLENGED,
            "answer_challenge",
            challenge.id,
            {"answer_id": str(answer.id), "question_id": str(question.id)},
        )
        await self.session.commit()
        await self.session.refresh(challenge)
        return AnswerChallengeResponse.model_validate(challenge)

    async def _sync_question_embedding(self, question: Question | None) -> None:
        if question is None:
            return
        try:
            await EmbeddingService(
                self.session, get_embedding_provider(self.settings)
            ).sync_question(question)
        except EmbeddingProviderError:
            logger.exception(
                "Failed to regenerate search embedding for question %s", question.id
            )
        except Exception:
            logger.exception("Failed to persist search embedding for question %s", question.id)

    async def list_challenges(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[AnswerChallengeResponse]:
        await self._visible_answer(answer_id, organisation_id, user_id)
        return [
            AnswerChallengeResponse.model_validate(item)
            for item in await self.governance.list_challenges(answer_id, organisation_id)
        ]

    async def decide_challenge(
        self,
        challenge_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: ChallengeDecision,
        *,
        accept: bool,
    ) -> AnswerChallengeResponse:
        challenge = await self.governance.get_challenge(
            challenge_id, organisation_id, for_update=True
        )
        if not challenge:
            raise NotFoundError("Challenge not found")
        if challenge.status != ChallengeStatus.OPEN:
            raise ConflictError("This challenge has already been reviewed")
        answer = await self.answers.get_for_organisation(challenge.answer_id, organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        question = await self.governance.get_question_for_update(
            answer.question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        await self.permissions.require_answer_manager(
            actor, question, self.governance, permission="review"
        )

        now = datetime.now(UTC)
        challenge.status = ChallengeStatus.ACCEPTED if accept else ChallengeStatus.REJECTED
        challenge.reviewed_by = actor.id
        challenge.reviewed_at = now
        challenge.reviewer_note = data.reviewer_note
        if accept:
            replacement_body = data.replacement_body or challenge.suggested_answer
            if replacement_body:
                await self.permissions.require_answer_manager(
                    actor, question, self.governance, permission="answer_approval"
                )
                await self._replace_answer(
                    answer,
                    question,
                    actor,
                    replacement_body,
                    data.review_days,
                    challenge.reason,
                )
            elif answer.status == AnswerStatus.VERIFIED:
                answer.review_due_at = now
            action = AuditAction.CHALLENGE_ACCEPTED
        else:
            action = AuditAction.CHALLENGE_REJECTED
        await self._audit(actor, action, "answer_challenge", challenge.id)
        await self.session.commit()
        await self.session.refresh(challenge)
        if accept:
            await self._sync_question_embedding(question)
        return AnswerChallengeResponse.model_validate(challenge)

    async def versions(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[AnswerVersionResponse]:
        answer, _, _ = await self._visible_answer(answer_id, organisation_id, user_id)
        return [
            AnswerVersionResponse.model_validate(
                {**version.__dict__, "changed_by": UserSummary.model_validate(changed_by)}
            )
            for version, changed_by in await self.governance.list_versions(
                answer.question_id, organisation_id
            )
        ]

    async def assign_department_owner(
        self,
        department_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        owner_user_id: UUID,
    ) -> DepartmentAnswerOwnerResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        department = await self.departments.get_for_organisation(
            department_id, organisation_id
        )
        owner = await self.users.get_for_organisation(owner_user_id, organisation_id)
        if not department or not owner:
            raise NotFoundError("Department or user not found in this organisation")
        if owner.role != UserRole.ANSWER_OWNER:
            raise ConflictError("Department owners must have the answer_owner role")
        existing = await self.governance.get_department_owner(
            organisation_id, department_id, owner_user_id
        )
        assignment = existing or DepartmentAnswerOwner(
            organisation_id=organisation_id,
            department_id=department_id,
            user_id=owner_user_id,
        )
        if not existing:
            await self.governance.add(assignment)
            await self._audit(
                actor,
                AuditAction.DEPARTMENT_OWNER_ASSIGNED,
                "department_answer_owner",
                assignment.id,
                {"department_id": str(department_id), "user_id": str(owner_user_id)},
            )
            await self.session.commit()
            await self.session.refresh(assignment)
        return DepartmentAnswerOwnerResponse.model_validate(
            {
                **assignment.__dict__,
                "department": DepartmentSummary.model_validate(department),
                "user": UserSummary.model_validate(owner),
            }
        )

    async def remove_department_owner(
        self,
        department_id: UUID,
        owner_user_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> None:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        assignment = await self.governance.get_department_owner(
            organisation_id, department_id, owner_user_id
        )
        if not assignment:
            raise NotFoundError("Department owner assignment not found")
        assignment_id = assignment.id
        await self.session.delete(assignment)
        await self._audit(
            actor,
            AuditAction.DEPARTMENT_OWNER_REMOVED,
            "department_answer_owner",
            assignment_id,
            {"department_id": str(department_id), "user_id": str(owner_user_id)},
        )
        await self.session.commit()

    async def list_department_owners(
        self,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[DepartmentAnswerOwnerResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        return [
            DepartmentAnswerOwnerResponse.model_validate(
                {
                    **assignment.__dict__,
                    "department": DepartmentSummary.model_validate(department),
                    "user": UserSummary.model_validate(owner),
                }
            )
            for assignment, department, owner in await self.governance.list_department_owners(
                organisation_id
            )
        ]

    async def my_department_owner_ids(
        self,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[UUID]:
        actor = await self.permissions.actor(user_id, organisation_id)
        if actor.role != UserRole.ANSWER_OWNER:
            raise PermissionDeniedError(
                "Only answer owners can view their department assignments"
            )
        return sorted(
            {
                department.id
                for _, department, owner in await self.governance.list_department_owners(
                    organisation_id
                )
                if owner.id == actor.id
            },
            key=str,
        )

    async def audit_events(
        self,
        organisation_id: UUID,
        user_id: UUID,
        limit: int,
    ) -> list[AuditEventResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        await self.permissions.require_admin(actor)
        return [
            AuditEventResponse.model_validate(
                {**event.__dict__, "metadata": event.event_metadata}
            )
            for event in await self.governance.list_audit_events(organisation_id, limit)
        ]

    async def review_queue(
        self,
        organisation_id: UUID,
        user_id: UUID,
        department_id: UUID | None = None,
        item_type: ReviewQueueType | None = None,
        status: ChallengeStatus | None = None,
    ) -> list[ReviewQueueItem]:
        actor = await self.permissions.actor(user_id, organisation_id)
        can_review_anywhere = await self.permissions.has_any_permission(
            actor, "review"
        )
        can_approve_anywhere = await self.permissions.has_any_permission(
            actor, "answer_approval"
        )
        if actor.role == UserRole.ANSWER_OWNER:
            department_ids = await self.governance.owned_department_ids(
                organisation_id, actor.id
            )
            if department_id is not None:
                department_ids = (
                    [department_id] if department_id in department_ids else []
                )
        elif can_review_anywhere or can_approve_anywhere:
            department_ids = None if department_id is None else [department_id]
        else:
            raise PermissionDeniedError("You do not have access to the review queue")

        now = datetime.now(UTC)
        challenges, due_answers, community_answers = (
            await self.governance.review_queue_rows(
                organisation_id,
                department_ids,
                now + timedelta(days=self.settings.review_due_soon_days),
                status or ChallengeStatus.OPEN,
            )
        )
        suggestion_status = (
            DuplicateSuggestionStatus(status.value)
            if status is not None and status.value != "withdrawn"
            else DuplicateSuggestionStatus.OPEN
        )
        suggestion_rows = (
            []
            if status is not None and status.value == "withdrawn"
            else await self.canonical.suggestion_rows(
                organisation_id, department_ids, suggestion_status
            )
        )
        async def may_access(question: Question, permission: str) -> bool:
            if not self.permissions.can_view_question(actor, question):
                return False
            department_id = question.department_id
            if department_id is None and question.team_id is not None:
                department_id = await self.governance.team_department_id(
                    question.team_id, organisation_id
                )
            if await self.permissions.has_permission(
                actor,
                permission,
                department_id=department_id,
                team_id=question.team_id,
            ):
                return True
            return bool(
                actor.role == UserRole.ANSWER_OWNER
                and department_id is not None
                and await self.governance.is_department_owner(
                    organisation_id, department_id, actor.id
                )
            )

        challenges = [
            row for row in challenges if await may_access(row[2], "review")
        ]
        due_answers = [
            row for row in due_answers if await may_access(row[1], "review")
        ]
        community_answers = [
            row
            for row in community_answers
            if await may_access(row[1], "answer_approval")
        ]
        suggestion_rows = [
            row
            for row in suggestion_rows
            if await may_access(row[1], "review")
            and await may_access(row[2], "review")
        ]
        items: list[ReviewQueueItem] = []
        if item_type in (None, ReviewQueueType.CHALLENGE):
            items.extend(
                ReviewQueueItem(
                    type=ReviewQueueType.CHALLENGE,
                    question_id=question.id,
                    question_title=question.title,
                    answer_id=answer.id,
                    department=DepartmentSummary.model_validate(department)
                    if department
                    else None,
                    relevant_at=challenge.created_at,
                    challenge_id=challenge.id,
                    challenge_type=challenge.type,
                    challenge_status=challenge.status,
                )
                for challenge, answer, question, department in challenges
            )
        if status is None and item_type in (
            None,
            ReviewQueueType.REVIEW_DUE,
            ReviewQueueType.REVIEW_DUE_SOON,
        ):
            for answer, question, department in due_answers:
                queue_type = (
                    ReviewQueueType.REVIEW_DUE
                    if answer.review_due_at and answer.review_due_at <= now
                    else ReviewQueueType.REVIEW_DUE_SOON
                )
                if item_type not in (None, queue_type):
                    continue
                items.append(
                    ReviewQueueItem(
                        type=queue_type,
                        question_id=question.id,
                        question_title=question.title,
                        answer_id=answer.id,
                        department=DepartmentSummary.model_validate(department)
                        if department
                        else None,
                        relevant_at=answer.review_due_at,
                    )
                )
        if status is None and item_type in (None, ReviewQueueType.NEEDS_VERIFICATION):
            seen_questions: set[UUID] = set()
            for answer, question, department in community_answers:
                if question.id in seen_questions:
                    continue
                seen_questions.add(question.id)
                items.append(
                    ReviewQueueItem(
                        type=ReviewQueueType.NEEDS_VERIFICATION,
                        question_id=question.id,
                        question_title=question.title,
                        answer_id=answer.id,
                        department=DepartmentSummary.model_validate(department)
                        if department
                        else None,
                        relevant_at=answer.created_at,
                    )
                )
        if item_type in (None, ReviewQueueType.DUPLICATE_SUGGESTION):
            items.extend(
                ReviewQueueItem(
                    type=ReviewQueueType.DUPLICATE_SUGGESTION,
                    question_id=question.id,
                    question_title=question.title,
                    department=DepartmentSummary.model_validate(department)
                    if department
                    else None,
                    relevant_at=suggestion.created_at,
                    duplicate_suggestion_id=suggestion.id,
                    duplicate_suggestion_status=suggestion.status,
                    suggested_canonical_question_id=target.id,
                    suggested_canonical_title=target.title,
                )
                for suggestion, question, target, department in suggestion_rows
            )
        items.sort(
            key=lambda item: item.relevant_at or datetime.min.replace(tzinfo=UTC)
        )
        return items

    async def _visible_answer(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> tuple[Answer, Question, User]:
        answer = await self.answers.get_for_organisation(answer_id, organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        if answer.archived_at is not None:
            raise ConflictError("Archived answers cannot be governed")
        question = await self.questions.get_for_organisation(
            answer.question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions cannot be governed")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        return answer, question, actor

    async def _managed_answer(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        *,
        permission: str = "answer_approval",
    ) -> tuple[Answer, Question, User]:
        answer, question, actor = await self._visible_answer(
            answer_id, organisation_id, user_id
        )
        locked_question = await self.governance.get_question_for_update(
            question.id, organisation_id
        )
        if not locked_question:
            raise NotFoundError("Question not found")
        await self.permissions.require_answer_manager(
            actor, locked_question, self.governance, permission=permission
        )
        return answer, locked_question, actor

    async def _supersede_current(
        self,
        question: Question,
        replacement_id: UUID,
        actor: User,
    ) -> None:
        previous = await self.governance.verified_answer(
            question.id,
            question.organisation_id,
            exclude_answer_id=replacement_id,
        )
        if not previous:
            return
        previous.status = AnswerStatus.SUPERSEDED
        await self._create_version(previous, actor, "Replaced by verified answer")
        await self._audit(
            actor, AuditAction.ANSWER_SUPERSEDED, "answer", previous.id
        )

    async def _replace_answer(
        self,
        previous: Answer,
        question: Question,
        actor: User,
        body: str,
        review_days: int | None,
        reason: str,
    ) -> Answer:
        now = datetime.now(UTC)
        if previous.status == AnswerStatus.VERIFIED:
            previous.status = AnswerStatus.SUPERSEDED
            await self._create_version(previous, actor, reason)
            await self._audit(
                actor, AuditAction.ANSWER_SUPERSEDED, "answer", previous.id
            )
        replacement = Answer(
            organisation_id=question.organisation_id,
            question_id=question.id,
            author_id=actor.id,
            body=body,
            status=AnswerStatus.VERIFIED,
            verified_by=actor.id,
            verified_at=now,
            last_reviewed_by=actor.id,
            last_reviewed_at=now,
            review_due_at=now + timedelta(
                days=review_days or self.settings.default_review_days
            ),
        )
        await self.answers.add(replacement)
        question.accepted_answer_id = replacement.id
        question.status = QuestionStatus.RESOLVED
        question.resolved_at = now
        await self._create_version(replacement, actor, reason)
        await self._audit(
            actor, AuditAction.ANSWER_VERIFIED, "answer", replacement.id
        )
        return replacement

    async def _create_version(
        self,
        answer: Answer,
        actor: User,
        reason: str | None,
    ) -> None:
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
            {"answer_id": str(answer.id), "version_number": version.version_number},
        )

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