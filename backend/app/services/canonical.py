import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import (
    EmbeddingProvider,
    EmbeddingProviderError,
    get_embedding_provider,
)
from app.ai.embedding_service import EmbeddingService
from app.core.config import Settings
from app.core.exceptions import ConflictError, NotFoundError
from app.models.answer import Answer, AnswerStatus
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditAction, AuditEvent
from app.models.duplicate_suggestion import (
    DuplicateSuggestion,
    DuplicateSuggestionStatus,
)
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.repositories.canonical import CanonicalRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.canonical import (
    DuplicateSuggestionCreate,
    DuplicateSuggestionDecision,
    DuplicateSuggestionResponse,
    MergeQuestionsRequest,
    MergeQuestionsResponse,
)
from app.schemas.search import SemanticSearchResult
from app.services.permissions import PermissionService
from app.services.search import SearchService

logger = logging.getLogger(__name__)


class CanonicalQuestionService:
    def __init__(
        self,
        session: AsyncSession,
        settings: Settings,
        embedding_provider: EmbeddingProvider | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.canonical = CanonicalRepository(session)
        self.governance = GovernanceRepository(session)
        self.teams = TeamRepository(session)
        self.permissions = PermissionService(UserRepository(session))
        self.embedding_provider = embedding_provider

    async def merge(
        self,
        canonical_question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: MergeQuestionsRequest,
    ) -> MergeQuestionsResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        response = await self._merge(canonical_question_id, organisation_id, actor, data)
        await self.session.commit()
        question = await self.canonical.question(canonical_question_id, organisation_id)
        await self._sync_embedding_for_question(question)
        return response

    async def unmerge(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        reason: str,
    ) -> Question:
        actor = await self.permissions.actor(user_id, organisation_id)
        question = await self.canonical.question(
            question_id, organisation_id, for_update=True
        )
        if not question:
            raise NotFoundError("Question not found")
        if question.canonical_question_id is None:
            raise ConflictError("Question is not linked to a canonical question")
        root = await self._root(question, organisation_id, actor)
        await self._require_manager(actor, question, root)
        previous_root_id = question.canonical_question_id
        question.canonical_question_id = None
        await self._audit(
            actor,
            AuditAction.QUESTION_UNMERGED,
            "question",
            question.id,
            {"previous_canonical_question_id": str(previous_root_id), "reason": reason},
        )
        await self.session.commit()
        await self.session.refresh(question)
        await self._sync_embedding_for_question(question)
        await self._sync_embedding_for_question(
            await self.canonical.question(previous_root_id, organisation_id)
        )
        return question

    async def _sync_embedding_for_question(self, question: Question | None) -> None:
        if question is None:
            return
        try:
            provider = self.embedding_provider or get_embedding_provider(self.settings)
            await EmbeddingService(self.session, provider).sync_question(question)
        except EmbeddingProviderError:
            logger.exception(
                "Failed to regenerate search embedding for question %s", question.id
            )
        except Exception:
            logger.exception(
                "Failed to persist search embedding for question %s", question.id
            )

    async def candidates(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        limit: int,
    ) -> list[SemanticSearchResult]:
        actor = await self.permissions.actor(user_id, organisation_id)
        question = await self.canonical.question(question_id, organisation_id)
        if not question:
            raise NotFoundError("Question not found")
        self.permissions.require_question_visibility(actor, question)
        if self.embedding_provider is None:
            raise RuntimeError("Embedding provider is required for duplicate candidates")
        query = "\n\n".join(
            part.strip() for part in (question.title, question.body or "") if part.strip()
        )
        results = await SearchService(
            self.session, self.embedding_provider, self.settings
        ).search(
            query=query,
            limit=min(limit + 2, 10),
            organisation_id=organisation_id,
            user_id=user_id,
        )
        current_root = (await self._root(question, organisation_id, actor)).id
        return [
            result
            for result in results
            if result.canonical_question_id != current_root
            and result.matched_question_id != question.id
        ][:limit]

    async def suggest(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: DuplicateSuggestionCreate,
    ) -> DuplicateSuggestionResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        question = await self.canonical.question(question_id, organisation_id)
        target = await self.canonical.question(
            data.suggested_canonical_question_id, organisation_id
        )
        if not question or not target:
            raise NotFoundError("Question not found")
        self.permissions.require_question_visibility(actor, question)
        self.permissions.require_question_visibility(actor, target)
        target = await self._root(target, organisation_id, actor)
        if question.id == target.id or question.canonical_question_id == target.id:
            raise ConflictError("Question already resolves to this canonical question")
        suggestion = DuplicateSuggestion(
            organisation_id=organisation_id,
            question_id=question.id,
            suggested_canonical_question_id=target.id,
            submitted_by=actor.id,
            reason=data.reason,
            status=DuplicateSuggestionStatus.OPEN,
        )
        try:
            await self.canonical.add(suggestion)
            await self._audit(
                actor,
                AuditAction.DUPLICATE_SUGGESTED,
                "duplicate_suggestion",
                suggestion.id,
                {
                    "question_id": str(question.id),
                    "suggested_canonical_question_id": str(target.id),
                },
            )
            await self.session.commit()
        except IntegrityError as error:
            await self.session.rollback()
            raise ConflictError("This duplicate has already been suggested") from error
        await self.session.refresh(suggestion)
        return self._suggestion_response(suggestion, question, target)

    async def decide_suggestion(
        self,
        suggestion_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: DuplicateSuggestionDecision,
        *,
        accept: bool,
    ) -> DuplicateSuggestionResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        suggestion = await self.canonical.suggestion(
            suggestion_id, organisation_id, for_update=True
        )
        if not suggestion:
            raise NotFoundError("Duplicate suggestion not found")
        if suggestion.status != DuplicateSuggestionStatus.OPEN:
            raise ConflictError("This duplicate suggestion has already been reviewed")
        question = await self.canonical.question(
            suggestion.question_id, organisation_id, for_update=True
        )
        target = await self.canonical.question(
            suggestion.suggested_canonical_question_id,
            organisation_id,
            for_update=True,
        )
        if not question or not target:
            raise NotFoundError("Question not found")
        target = await self._root(target, organisation_id, actor)
        await self._require_manager(actor, question, target)
        if accept:
            await self._merge(
                target.id,
                organisation_id,
                actor,
                MergeQuestionsRequest(
                    duplicate_question_ids=[question.id],
                    canonical_answer_id=data.canonical_answer_id,
                    reason=data.reason or "Accepted duplicate suggestion",
                ),
            )
            suggestion.status = DuplicateSuggestionStatus.ACCEPTED
            action = AuditAction.DUPLICATE_SUGGESTION_ACCEPTED
        else:
            suggestion.status = DuplicateSuggestionStatus.REJECTED
            action = AuditAction.DUPLICATE_SUGGESTION_REJECTED
        suggestion.reviewed_by = actor.id
        suggestion.reviewed_at = datetime.now(UTC)
        if not accept:
            await self._audit(actor, action, "duplicate_suggestion", suggestion.id)
        await self.session.commit()
        await self.session.refresh(suggestion)
        if accept:
            await self._sync_embedding_for_question(target)
        return self._suggestion_response(suggestion, question, target)

    async def _merge(
        self,
        canonical_question_id: UUID,
        organisation_id: UUID,
        actor: User,
        data: MergeQuestionsRequest,
    ) -> MergeQuestionsResponse:
        canonical = await self.canonical.question(
            canonical_question_id, organisation_id, for_update=True
        )
        if not canonical:
            raise NotFoundError("Canonical question not found")
        canonical = await self._root(canonical, organisation_id, actor)
        requested: list[Question] = []
        for question_id in dict.fromkeys(data.duplicate_question_ids):
            question = await self.canonical.question(
                question_id, organisation_id, for_update=True
            )
            if not question:
                raise NotFoundError("Duplicate question not found")
            if question.id == canonical.id:
                raise ConflictError("A question cannot be merged into itself")
            if (await self._root(question, organisation_id, actor)).id == canonical.id:
                raise ConflictError("Question is already linked to this canonical question")
            requested.append(question)

        affected = {question.id: question for question in requested}
        frontier = set(affected)
        while frontier:
            descendants = await self.canonical.descendants(frontier, organisation_id)
            frontier = {
                question.id for question in descendants if question.id not in affected
            }
            affected.update((question.id, question) for question in descendants)
        for question in (canonical, *affected.values()):
            await self._validate_structure(question, organisation_id)
        await self._require_manager(actor, canonical, *affected.values())

        selected = None
        if data.canonical_answer_id:
            selected = await self.canonical.answer(
                data.canonical_answer_id, organisation_id
            )
            if not selected or selected.question_id not in {canonical.id, *affected}:
                raise NotFoundError("Canonical answer is not attached to these questions")
            if selected.status in (AnswerStatus.REJECTED, AnswerStatus.SUPERSEDED):
                raise ConflictError("This answer cannot become canonical")
        else:
            canonical_answer = (
                await self.canonical.answer(canonical.accepted_answer_id, organisation_id)
                if canonical.accepted_answer_id
                else None
            )
            reusable = await self.canonical.reusable_answers(
                set(affected), organisation_id
            )
            accepted_ids = {
                question.accepted_answer_id
                for question in affected.values()
                if question.accepted_answer_id
            }
            meaningful = [
                answer
                for answer in reusable
                if answer.status == AnswerStatus.VERIFIED or answer.id in accepted_ids
            ]
            baseline = canonical_answer.body.strip() if canonical_answer else None
            if any(answer.body.strip() != baseline for answer in meaningful):
                raise ConflictError(
                    "Duplicate answers differ; select canonical_answer_id before merging"
                )

        previous_answer_id = canonical.accepted_answer_id
        if selected is not None:
            canonical.accepted_answer_id = await self._select_answer(
                canonical, selected, actor, data.reason
            )
            canonical.status = QuestionStatus.RESOLVED
            canonical.resolved_at = canonical.resolved_at or datetime.now(UTC)
        for question in affected.values():
            question.canonical_question_id = canonical.id
            await self._audit(
                actor,
                AuditAction.QUESTION_MERGED,
                "question",
                question.id,
                {
                    "canonical_question_id": str(canonical.id),
                    "reason": data.reason,
                },
            )
        if canonical.accepted_answer_id != previous_answer_id:
            await self._audit(
                actor,
                AuditAction.CANONICAL_ANSWER_CHANGED,
                "question",
                canonical.id,
                {
                    "previous_answer_id": str(previous_answer_id)
                    if previous_answer_id
                    else None,
                    "canonical_answer_id": str(canonical.accepted_answer_id),
                    "source_answer_id": str(selected.id) if selected else None,
                },
            )
        for suggestion in await self.canonical.related_open_suggestions(
            organisation_id, {canonical.id, *affected}
        ):
            if (
                suggestion.question_id in affected
                and suggestion.suggested_canonical_question_id == canonical.id
            ):
                suggestion.status = DuplicateSuggestionStatus.ACCEPTED
                suggestion.reviewed_by = actor.id
                suggestion.reviewed_at = datetime.now(UTC)
                await self._audit(
                    actor,
                    AuditAction.DUPLICATE_SUGGESTION_ACCEPTED,
                    "duplicate_suggestion",
                    suggestion.id,
                )
        return MergeQuestionsResponse(
            canonical_question_id=canonical.id,
            merged_question_ids=list(affected),
            canonical_answer_id=canonical.accepted_answer_id,
        )

    async def _root(
        self, question: Question, organisation_id: UUID, actor: User
    ) -> Question:
        seen = {question.id}
        current = question
        self.permissions.require_question_visibility(actor, current)
        while current.canonical_question_id is not None:
            if current.canonical_question_id in seen:
                raise ConflictError("Circular canonical question relationship detected")
            seen.add(current.canonical_question_id)
            parent = await self.canonical.question(
                current.canonical_question_id, organisation_id, for_update=True
            )
            if not parent:
                raise NotFoundError("Canonical question not found")
            self.permissions.require_question_visibility(actor, parent)
            current = parent
        return current

    async def _require_manager(self, actor: User, *questions: Question) -> None:
        for question in questions:
            self.permissions.require_question_visibility(actor, question)
            await self.permissions.require_answer_manager(
                actor, question, self.governance
            )

    async def _validate_structure(
        self,
        question: Question,
        organisation_id: UUID,
    ) -> None:
        if question.team_id is None:
            return
        row = await self.teams.get(question.team_id, organisation_id)
        if not row:
            raise ConflictError("Question references an invalid team")
        team, _ = row
        if (
            team.department_id is not None
            and question.department_id is not None
            and team.department_id != question.department_id
        ):
            raise ConflictError("Question team and department do not match")

    async def _select_answer(
        self,
        canonical: Question,
        selected: Answer,
        actor: User,
        reason: str,
    ) -> UUID:
        if selected.question_id == canonical.id:
            return selected.id
        status = (
            AnswerStatus.VERIFIED
            if selected.status == AnswerStatus.VERIFIED
            else AnswerStatus.COMMUNITY
        )
        if status == AnswerStatus.VERIFIED:
            previous = await self.governance.verified_answer(
                canonical.id, canonical.organisation_id
            )
            if previous:
                previous.status = AnswerStatus.SUPERSEDED
                await self._create_version(previous, actor, reason)
                await self._audit(
                    actor,
                    AuditAction.ANSWER_SUPERSEDED,
                    "answer",
                    previous.id,
                )
                await self.session.flush()
        copied = Answer(
            organisation_id=canonical.organisation_id,
            question_id=canonical.id,
            author_id=selected.author_id,
            body=selected.body,
            status=status,
            verified_by=selected.verified_by,
            verified_at=selected.verified_at,
            review_due_at=selected.review_due_at,
            last_reviewed_at=selected.last_reviewed_at,
            last_reviewed_by=selected.last_reviewed_by,
        )
        await self.canonical.add(copied)
        if status == AnswerStatus.VERIFIED:
            await self._create_version(copied, actor, reason)
        return copied.id

    async def _create_version(
        self,
        answer: Answer,
        actor: User,
        reason: str,
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
        await self.canonical.add(version)
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
        await self.canonical.add(
            AuditEvent(
                organisation_id=actor.organisation_id,
                actor_id=actor.id,
                action=action.value,
                entity_type=entity_type,
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )

    @staticmethod
    def _suggestion_response(
        suggestion: DuplicateSuggestion,
        question: Question,
        target: Question,
    ) -> DuplicateSuggestionResponse:
        return DuplicateSuggestionResponse.model_validate(
            {
                **suggestion.__dict__,
                "question_title": question.title,
                "suggested_canonical_title": target.title,
            }
        )