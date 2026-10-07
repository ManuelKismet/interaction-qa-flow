from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import EmbeddingProvider, get_embedding_provider
from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.models.audit_event import AuditAction, AuditEvent
from app.models.guided import (
    GuidedSessionVisibility,
    KnowledgeProposal,
    KnowledgeProposalStatus,
)
from app.models.question import QuestionVisibility
from app.repositories.governance import GovernanceRepository
from app.repositories.department import DepartmentRepository
from app.repositories.guided import GuidedRepository
from app.repositories.question import QuestionRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.answer import AnswerCreate
from app.schemas.guided import (
    KnowledgeProposalCreate,
    KnowledgeProposalDecision,
    KnowledgeProposalResponse,
)
from app.schemas.question import QuestionCreate
from app.schemas.search import SemanticSearchResult
from app.services.answer import AnswerService
from app.services.permissions import PermissionService
from app.services.question import QuestionService
from app.services.search import SearchService


class GuidedKnowledgeService:
    def __init__(
        self,
        session: AsyncSession,
        settings: Settings | None = None,
        provider: EmbeddingProvider | None = None,
    ) -> None:
        self.session = session
        self.settings = settings or get_settings()
        self.provider = provider or get_embedding_provider(self.settings)
        self.guided = GuidedRepository(session)
        self.departments = DepartmentRepository(session)
        self.questions = QuestionRepository(session)
        self.teams = TeamRepository(session)
        self.users = UserRepository(session)
        self.governance = GovernanceRepository(session)
        self.permissions = PermissionService(self.users)

    async def create_proposal(
        self,
        organisation_id: UUID,
        user_id: UUID,
        data: KnowledgeProposalCreate,
    ) -> KnowledgeProposalResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        question = await self.guided.question(data.guided_question_id, organisation_id)
        answer = await self.guided.answer(data.guided_answer_id, organisation_id)
        if not question or not answer or answer.question_id != question.id:
            raise NotFoundError("Guided question and answer pair not found")
        session = await self.guided.guided_session(question.session_id, organisation_id)
        if not session:
            raise NotFoundError("Guided session not found")
        if actor.id != session.created_by and (
            session.visibility == GuidedSessionVisibility.PRIVATE
            or not await self.permissions.is_organisation_admin(actor)
        ):
            raise PermissionDeniedError("Only the session owner can use private-session content")
        if not answer.body.strip():
            raise ConflictError("An empty answer cannot be proposed as knowledge")
        department_id = data.department_id if data.department_id is not None else session.department_id
        team_id = data.team_id if data.team_id is not None else session.team_id
        await self._validate_team(department_id, team_id, organisation_id)
        proposal = KnowledgeProposal(
            organisation_id=organisation_id,
            guided_session_id=session.id,
            guided_question_id=question.id,
            guided_answer_id=answer.id,
            proposed_by=user_id,
            proposed_question_text=(data.proposed_question_text or question.text).strip(),
            proposed_answer_text=(data.proposed_answer_text or answer.body).strip(),
            department_id=department_id,
            team_id=team_id,
            status=KnowledgeProposalStatus.PENDING,
        )
        await self.guided.add(proposal)
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.KNOWLEDGE_PROPOSAL_CREATED,
            proposal.id,
            {"guided_session_id": str(session.id)},
        )
        await self.session.commit()
        await self.session.refresh(proposal)
        return KnowledgeProposalResponse.model_validate(proposal)

    async def list_proposals(
        self, organisation_id: UUID, user_id: UUID
    ) -> list[KnowledgeProposalResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        visible = []
        for item in await self.guided.proposals(organisation_id):
            if await self.permissions.has_permission(
                actor,
                "review",
                department_id=item.department_id,
                team_id=item.team_id,
            ):
                visible.append(KnowledgeProposalResponse.model_validate(item))
        return visible

    async def duplicates(
        self,
        proposal_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        limit: int = 5,
    ) -> list[SemanticSearchResult]:
        proposal = await self._proposal(proposal_id, organisation_id)
        return await self.search(
            proposal.proposed_question_text, organisation_id, user_id, limit
        )

    async def search(
        self,
        query: str,
        organisation_id: UUID,
        user_id: UUID,
        limit: int = 5,
    ) -> list[SemanticSearchResult]:
        return await SearchService(self.session, self.provider, self.settings).search(
            query=query,
            limit=limit,
            organisation_id=organisation_id,
            user_id=user_id,
        )

    async def search_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        query: str | None,
        limit: int,
    ) -> list[SemanticSearchResult]:
        question = await self.guided.question(question_id, organisation_id)
        if not question:
            raise NotFoundError("Guided question not found")
        guided_session = await self.guided.guided_session(question.session_id, organisation_id)
        actor = await self.permissions.actor(user_id, organisation_id)
        if not guided_session or (
            actor.id != guided_session.created_by
            and (
                guided_session.visibility == GuidedSessionVisibility.PRIVATE
                or not await self.permissions.is_organisation_admin(actor)
            )
        ):
            raise PermissionDeniedError("Only the session owner can use private-session content")
        return await self.search(query or question.text, organisation_id, user_id, limit)

    async def decide(
        self,
        proposal_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: KnowledgeProposalDecision,
    ) -> KnowledgeProposalResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        proposal = await self._proposal(proposal_id, organisation_id)
        await self.permissions.require_permission(
            actor,
            "review",
            department_id=proposal.department_id,
            team_id=proposal.team_id,
        )
        if proposal.status != KnowledgeProposalStatus.PENDING:
            raise ConflictError("Knowledge proposal has already been reviewed")
        question = None
        question_service = None
        try:
            now = datetime.now(UTC)
            if data.action == "reject":
                proposal.status = KnowledgeProposalStatus.REJECTED
                action = AuditAction.KNOWLEDGE_PROPOSAL_REJECTED
            elif data.action == "link":
                if not data.existing_question_id:
                    raise ConflictError("Linking requires an existing question")
                existing = await self.questions.get_for_organisation(
                    data.existing_question_id, organisation_id
                )
                if not existing:
                    raise NotFoundError("Existing knowledge question not found")
                proposal.status = KnowledgeProposalStatus.DUPLICATE
                proposal.linked_question_id = (
                    existing.canonical_question_id or existing.id
                )
                action = AuditAction.KNOWLEDGE_PROPOSAL_LINKED_TO_EXISTING
            else:
                question_service = QuestionService(
                    self.session, embedding_provider=self.provider
                )
                question = await question_service.create(
                    QuestionCreate(
                        organisation_id=organisation_id,
                        author_id=proposal.proposed_by,
                        department_id=proposal.department_id,
                        team_id=proposal.team_id,
                        title=proposal.proposed_question_text,
                        body=(
                            f"Proposed from Guided session {proposal.guided_session_id}."
                        ),
                        visibility=(
                            QuestionVisibility.DEPARTMENT
                            if proposal.department_id
                            else QuestionVisibility.ORGANISATION
                        ),
                    ),
                    commit=False,
                    sync_embedding=False,
                )
                await AnswerService(self.session).create(
                    question.id,
                    AnswerCreate(
                        organisation_id=organisation_id,
                        author_id=proposal.proposed_by,
                        body=proposal.proposed_answer_text,
                    ),
                    commit=False,
                )
                proposal.status = KnowledgeProposalStatus.ACCEPTED
                proposal.created_question_id = question.id
                action = AuditAction.KNOWLEDGE_PROPOSAL_ACCEPTED
            proposal.reviewed_by = user_id
            proposal.reviewed_at = now
            await self._audit(
                organisation_id,
                user_id,
                action,
                proposal.id,
                {
                    "created_question_id": str(proposal.created_question_id)
                    if proposal.created_question_id
                    else None,
                    "linked_question_id": str(proposal.linked_question_id)
                    if proposal.linked_question_id
                    else None,
                },
            )
            await self.session.commit()
        except Exception:
            await self.session.rollback()
            raise
        await self.session.refresh(proposal)
        if question is not None and question_service is not None:
            await question_service._sync_embedding_safely(question)
        return KnowledgeProposalResponse.model_validate(proposal)

    async def _proposal(
        self, proposal_id: UUID, organisation_id: UUID
    ) -> KnowledgeProposal:
        proposal = await self.guided.proposal(proposal_id, organisation_id)
        if not proposal:
            raise NotFoundError("Knowledge proposal not found")
        return proposal

    async def _validate_team(
        self,
        department_id: UUID | None,
        team_id: UUID | None,
        organisation_id: UUID,
    ) -> None:
        if department_id and not await self.departments.get_for_organisation(
            department_id, organisation_id
        ):
            raise NotFoundError("Department not found in this organisation")
        if not team_id:
            return
        row = await self.teams.get(team_id, organisation_id)
        if not row:
            raise NotFoundError("Team not found in this organisation")
        team, _ = row
        if team.department_id and department_id and team.department_id != department_id:
            raise ConflictError("Team does not belong to the selected department")

    async def _audit(
        self,
        organisation_id: UUID,
        actor_id: UUID,
        action: AuditAction,
        entity_id: UUID,
        metadata: dict | None = None,
    ) -> None:
        await self.governance.add(
            AuditEvent(
                organisation_id=organisation_id,
                actor_id=actor_id,
                action=action.value,
                entity_type="knowledge_proposal",
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )