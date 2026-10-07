import csv
import io
import unicodedata
from datetime import UTC, datetime
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.models.audit_event import AuditAction, AuditEvent
from app.models.guided import (
    GuidedAnswer,
    GuidedParticipant,
    GuidedQuestion,
    GuidedQuestionScope,
    GuidedQuestionSource,
    GuidedSession,
    GuidedSessionRevision,
    GuidedSessionStatus,
    GuidedSessionVisibility,
    GuidedTemplate,
    GuidedTemplateQuestion,
    GuidedTemplateStatus,
    GuidedTemplateVersion,
)
from app.repositories.department import DepartmentRepository
from app.repositories.governance import GovernanceRepository
from app.repositories.guided import GuidedRepository
from app.repositories.question import QuestionRepository
from app.repositories.team import TeamRepository
from app.repositories.user import UserRepository
from app.schemas.guided import (
    GuidedAnswerResponse,
    GuidedAnswerUpdate,
    GuidedAnswerUpsert,
    GuidedFlowQuestion,
    GuidedFollowUpCreate,
    GuidedParticipantCreate,
    GuidedParticipantResponse,
    GuidedParticipantUpdate,
    GuidedQuestionCreate,
    GuidedQuestionResponse,
    GuidedQuestionUpdate,
    GuidedRevisionResponse,
    GuidedSessionCreate,
    GuidedSessionResponse,
    GuidedSessionSummary,
    GuidedSessionUpdate,
    GuidedTemplateCreate,
    GuidedTemplateImportRequest,
    GuidedTemplateQuestionInput,
    GuidedTemplateQuestionResponse,
    GuidedTemplateResponse,
    GuidedTemplateUpdate,
    GuidedTemplateVersionCreate,
    GuidedTemplateVersionResponse,
    GuidedViewMode,
    LegacyImportResponse,
)
from app.services.permissions import PermissionService


def _spreadsheet_safe_csv_cell(value: str) -> str:
    """Prefix formula-like or control-prefixed text so spreadsheets treat it as data."""
    if not value:
        return value
    if unicodedata.category(value[0]) in {"Cc", "Cf"}:
        return f"'{value}"

    index = 0
    while index < len(value) and (
        value[index].isspace()
        or unicodedata.category(value[index]) in {"Cc", "Cf"}
    ):
        index += 1
    if index < len(value) and value[index] in {"=", "+", "-", "@"}:
        return f"'{value}"
    return value


class GuidedService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.guided = GuidedRepository(session)
        self.departments = DepartmentRepository(session)
        self.teams = TeamRepository(session)
        self.users = UserRepository(session)
        self.questions = QuestionRepository(session)
        self.governance = GovernanceRepository(session)
        self.permissions = PermissionService(self.users)

    async def list_sessions(
        self,
        organisation_id: UUID,
        user_id: UUID,
        status: GuidedSessionStatus | None = None,
    ) -> list[GuidedSessionSummary]:
        actor = await self.permissions.actor(user_id, organisation_id)
        team_ids = await self.teams.team_ids_for_user(user_id, organisation_id)
        sessions = await self.guided.visible_sessions(
            organisation_id,
            user_id,
            actor.department_id,
            team_ids,
            await self.permissions.is_organisation_admin(actor),
            status,
        )
        return [GuidedSessionSummary.model_validate(item) for item in sessions]

    async def create_session(
        self,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedSessionCreate,
    ) -> GuidedSessionResponse:
        await self.permissions.actor(user_id, organisation_id)
        await self._validate_structure(
            data.department_id,
            data.team_id,
            organisation_id,
            require_department=data.visibility == GuidedSessionVisibility.DEPARTMENT,
        )
        template = None
        version = None
        if data.template_id:
            template = await self.guided.template(data.template_id, organisation_id)
            if not template or template.status == GuidedTemplateStatus.ARCHIVED:
                raise NotFoundError("Guided template not found")
            version = (
                await self.guided.template_version(data.template_version_id, organisation_id)
                if data.template_version_id
                else await self.guided.current_template_version(template)
            )
            if not version or version.template_id != template.id:
                raise NotFoundError("Guided template version not found")
        session = GuidedSession(
            organisation_id=organisation_id,
            created_by=user_id,
            template_id=template.id if template else None,
            template_version_id=version.id if version else None,
            title=data.title,
            owner_text=data.owner_text,
            context_reference=data.context_reference,
            department_id=data.department_id,
            team_id=data.team_id,
            visibility=data.visibility,
            status=GuidedSessionStatus.DRAFT,
            revision=1,
        )
        await self.guided.add(session)
        if version:
            await self._instantiate_template(session, version, user_id)
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_SESSION_CREATED,
            "guided_session",
            session.id,
            {"template_version_id": str(version.id) if version else None},
        )
        await self.session.commit()
        return await self.get_session(session.id, organisation_id, user_id)

    async def get_session(
        self,
        session_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        participant_id: UUID | None = None,
        view_mode: GuidedViewMode = GuidedViewMode.ALL_RELEVANT,
    ) -> GuidedSessionResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        session = await self._session(session_id, organisation_id)
        await self._require_view(actor, session)
        participants = await self.guided.participants(session.id, organisation_id)
        if participant_id and not any(item.id == participant_id for item in participants):
            raise NotFoundError("Participant not found in this session")
        questions = await self.guided.questions(session.id, organisation_id)
        answers = await self.guided.answers(session.id, organisation_id)
        flow = self._build_flow(questions, answers, participant_id, view_mode)
        return GuidedSessionResponse.model_validate(
            {
                **session.__dict__,
                "participants": [GuidedParticipantResponse.model_validate(item) for item in participants],
                "questions": flow,
                "prepared_question_count": sum(
                    item.source != GuidedQuestionSource.FOLLOW_UP for item in questions
                ),
                "follow_up_count": sum(
                    item.source == GuidedQuestionSource.FOLLOW_UP for item in questions
                ),
            }
        )

    async def update_session(
        self,
        session_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedSessionUpdate,
    ) -> GuidedSessionResponse:
        session = await self._owned_session(session_id, organisation_id, user_id)
        if data.expected_revision and data.expected_revision != session.revision:
            raise ConflictError("Session changed since it was loaded")
        changes = data.model_dump(exclude_unset=True, exclude={"expected_revision"})
        visibility = changes.get("visibility", session.visibility)
        await self._validate_structure(
            changes.get("department_id", session.department_id),
            changes.get("team_id", session.team_id),
            organisation_id,
            require_department=visibility == GuidedSessionVisibility.DEPARTMENT,
        )
        for field, value in changes.items():
            setattr(session, field, value)
        await self._save_revision(session, user_id, "Session details updated")
        await self.session.commit()
        return await self.get_session(session.id, organisation_id, user_id)

    async def transition_session(
        self,
        session_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        target: GuidedSessionStatus,
    ) -> GuidedSessionResponse:
        session = await self._owned_session(session_id, organisation_id, user_id)
        allowed = {
            GuidedSessionStatus.DRAFT: {GuidedSessionStatus.ACTIVE, GuidedSessionStatus.ARCHIVED},
            GuidedSessionStatus.ACTIVE: {GuidedSessionStatus.COMPLETED, GuidedSessionStatus.ARCHIVED},
            GuidedSessionStatus.COMPLETED: {GuidedSessionStatus.ARCHIVED},
            GuidedSessionStatus.ARCHIVED: set(),
        }
        if target not in allowed[session.status]:
            raise ConflictError(f"Cannot move session from {session.status.value} to {target.value}")
        session.status = target
        now = datetime.now(UTC)
        if target == GuidedSessionStatus.ACTIVE:
            session.started_at = session.started_at or now
            action = AuditAction.GUIDED_SESSION_STARTED
        elif target == GuidedSessionStatus.COMPLETED:
            session.completed_at = now
            action = AuditAction.GUIDED_SESSION_COMPLETED
        else:
            action = AuditAction.GUIDED_SESSION_ARCHIVED
        await self._save_revision(session, user_id, f"Session {target.value}")
        await self._audit(organisation_id, user_id, action, "guided_session", session.id)
        await self.session.commit()
        return await self.get_session(session.id, organisation_id, user_id)

    async def add_participant(
        self,
        session_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedParticipantCreate,
    ) -> GuidedParticipantResponse:
        session = await self._owned_session(session_id, organisation_id, user_id)
        if data.linked_user_id and not await self.users.get_for_organisation(
            data.linked_user_id, organisation_id
        ):
            raise NotFoundError("Linked user not found in this organisation")
        participant = GuidedParticipant(
            organisation_id=organisation_id,
            session_id=session.id,
            **data.model_dump(),
        )
        await self.guided.add(participant)
        await self._save_revision(session, user_id, "Participant added")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_PARTICIPANT_ADDED,
            "guided_participant",
            participant.id,
            {"session_id": str(session.id)},
        )
        await self.session.commit()
        await self.session.refresh(participant)
        return GuidedParticipantResponse.model_validate(participant)

    async def update_participant(
        self,
        participant_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedParticipantUpdate,
    ) -> GuidedParticipantResponse:
        participant = await self._participant(participant_id, organisation_id)
        session = await self._owned_session(participant.session_id, organisation_id, user_id)
        changes = data.model_dump(exclude_unset=True)
        if changes.get("linked_user_id") and not await self.users.get_for_organisation(
            changes["linked_user_id"], organisation_id
        ):
            raise NotFoundError("Linked user not found in this organisation")
        for field, value in changes.items():
            setattr(participant, field, value)
        await self._save_revision(session, user_id, "Participant updated")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_PARTICIPANT_UPDATED,
            "guided_participant",
            participant.id,
            {"session_id": str(session.id)},
        )
        await self.session.commit()
        await self.session.refresh(participant)
        return GuidedParticipantResponse.model_validate(participant)

    async def remove_participant(
        self, participant_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> None:
        participant = await self._participant(participant_id, organisation_id)
        session = await self._owned_session(participant.session_id, organisation_id, user_id)
        answers = await self.guided.answers(session.id, organisation_id)
        questions = await self.guided.questions(session.id, organisation_id, include_deleted=True)
        if any(item.participant_id == participant.id for item in answers) or any(
            item.target_participant_id == participant.id for item in questions
        ):
            raise ConflictError("Participant with questions or answers cannot be removed")
        await self.guided.delete(participant)
        await self._save_revision(session, user_id, "Participant removed")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_PARTICIPANT_REMOVED,
            "guided_participant",
            participant.id,
            {"session_id": str(session.id)},
        )
        await self.session.commit()

    async def add_question(
        self,
        session_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedQuestionCreate,
    ) -> GuidedQuestionResponse:
        session = await self._owned_session(session_id, organisation_id, user_id)
        if data.target_participant_id:
            participant = await self._participant(data.target_participant_id, organisation_id)
            if participant.session_id != session.id:
                raise NotFoundError("Participant not found in this session")
        if data.knowledge_question_id and not await self.questions.get_for_organisation(
            data.knowledge_question_id, organisation_id
        ):
            raise NotFoundError("Knowledge question not found")
        order = data.main_order_index
        if order is None:
            roots = [
                item
                for item in await self.guided.questions(session.id, organisation_id)
                if item.triggering_answer_id is None
            ]
            order = max((item.main_order_index or 0 for item in roots), default=-1) + 1
        question = GuidedQuestion(
            organisation_id=organisation_id,
            session_id=session.id,
            created_by=user_id,
            text=data.text,
            scope=data.scope,
            target_participant_id=data.target_participant_id,
            source=GuidedQuestionSource.MANUAL,
            main_order_index=order,
            knowledge_question_id=data.knowledge_question_id,
        )
        await self.guided.add(question)
        action = (
            AuditAction.GUIDED_SHARED_QUESTION_ADDED
            if data.scope == GuidedQuestionScope.SHARED
            else AuditAction.GUIDED_PARTICIPANT_QUESTION_ADDED
        )
        await self._save_revision(session, user_id, "Question added")
        await self._audit(
            organisation_id,
            user_id,
            action,
            "guided_question",
            question.id,
            {"session_id": str(session.id), "scope": data.scope.value},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return GuidedQuestionResponse.model_validate(question)

    async def add_follow_up(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedFollowUpCreate,
    ) -> GuidedQuestionResponse:
        answer = await self._answer(answer_id, organisation_id)
        session = await self._owned_session(answer.session_id, organisation_id, user_id)
        branches = [
            item
            for item in await self.guided.questions(session.id, organisation_id)
            if item.triggering_answer_id == answer.id
        ]
        order = data.branch_order_index
        if order is None:
            order = max((item.branch_order_index or 0 for item in branches), default=-1) + 1
        question = GuidedQuestion(
            organisation_id=organisation_id,
            session_id=session.id,
            created_by=user_id,
            text=data.text,
            scope=GuidedQuestionScope.PARTICIPANT,
            target_participant_id=answer.participant_id,
            source=GuidedQuestionSource.FOLLOW_UP,
            branch_order_index=order,
            triggering_answer_id=answer.id,
        )
        await self.guided.add(question)
        await self._save_revision(session, user_id, "Follow-up added")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_FOLLOWUP_ADDED,
            "guided_question",
            question.id,
            {"session_id": str(session.id), "triggering_answer_id": str(answer.id)},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return GuidedQuestionResponse.model_validate(question)

    async def update_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedQuestionUpdate,
    ) -> GuidedQuestionResponse:
        question = await self._question(question_id, organisation_id)
        session = await self._owned_session(question.session_id, organisation_id, user_id)
        changes = data.model_dump(exclude_unset=True)
        if changes.get("knowledge_question_id") and not await self.questions.get_for_organisation(
            changes["knowledge_question_id"], organisation_id
        ):
            raise NotFoundError("Knowledge question not found")
        for field, value in changes.items():
            setattr(question, field, value)
        await self._save_revision(session, user_id, "Question updated")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_QUESTION_UPDATED,
            "guided_question",
            question.id,
            {"session_id": str(session.id)},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return GuidedQuestionResponse.model_validate(question)

    async def set_question_deleted(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        deleted: bool,
    ) -> GuidedQuestionResponse:
        question = await self._question(question_id, organisation_id)
        session = await self._owned_session(question.session_id, organisation_id, user_id)
        question.deleted_at = datetime.now(UTC) if deleted else None
        action = AuditAction.GUIDED_QUESTION_DELETED if deleted else AuditAction.GUIDED_QUESTION_RESTORED
        await self._save_revision(session, user_id, "Question deleted" if deleted else "Question restored")
        await self._audit(
            organisation_id,
            user_id,
            action,
            "guided_question",
            question.id,
            {"session_id": str(session.id)},
        )
        await self.session.commit()
        await self.session.refresh(question)
        return GuidedQuestionResponse.model_validate(question)

    async def upsert_answer(
        self,
        question_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedAnswerUpsert,
    ) -> GuidedAnswerResponse:
        question = await self._question(question_id, organisation_id)
        session = await self._owned_session(question.session_id, organisation_id, user_id)
        participant = await self._participant(data.participant_id, organisation_id)
        if participant.session_id != session.id:
            raise NotFoundError("Participant not found in this session")
        if (
            question.scope == GuidedQuestionScope.PARTICIPANT
            and question.target_participant_id != participant.id
        ):
            raise ConflictError("This question belongs to another participant")
        if question.triggering_answer_id:
            parent = await self._answer(question.triggering_answer_id, organisation_id)
            if parent.participant_id != participant.id:
                raise ConflictError("Follow-up answers must remain on the triggering participant branch")
        answer = await self.guided.answer_for_question(question.id, participant.id, organisation_id)
        created = answer is None
        if answer is None:
            answer = GuidedAnswer(
                organisation_id=organisation_id,
                session_id=session.id,
                question_id=question.id,
                participant_id=participant.id,
                answered_by_user_id=user_id,
                body=data.body,
                branches_collapsed=data.branches_collapsed,
            )
            await self.guided.add(answer)
        else:
            answer.body = data.body
            answer.branches_collapsed = data.branches_collapsed
            answer.answered_by_user_id = user_id
        await self._save_revision(session, user_id, "Answer saved")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_ANSWER_ADDED if created else AuditAction.GUIDED_ANSWER_UPDATED,
            "guided_answer",
            answer.id,
            {"session_id": str(session.id), "question_id": str(question.id)},
        )
        try:
            await self.session.commit()
        except IntegrityError as error:
            await self.session.rollback()
            raise ConflictError("Answer was updated by another request") from error
        await self.session.refresh(answer)
        return GuidedAnswerResponse.model_validate(answer)

    async def update_answer(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedAnswerUpdate,
    ) -> GuidedAnswerResponse:
        answer = await self._answer(answer_id, organisation_id)
        session = await self._owned_session(answer.session_id, organisation_id, user_id)
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(answer, field, value)
        answer.answered_by_user_id = user_id
        await self._save_revision(session, user_id, "Answer saved")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_ANSWER_UPDATED,
            "guided_answer",
            answer.id,
            {"session_id": str(session.id), "question_id": str(answer.question_id)},
        )
        await self.session.commit()
        await self.session.refresh(answer)
        return GuidedAnswerResponse.model_validate(answer)

    async def revisions(
        self, session_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> list[GuidedRevisionResponse]:
        actor = await self.permissions.actor(user_id, organisation_id)
        session = await self._session(session_id, organisation_id)
        await self._require_view(actor, session)
        return [
            GuidedRevisionResponse.model_validate(item)
            for item in await self.guided.revisions(session.id, organisation_id)
        ]

    async def export_json(
        self, session_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> dict[str, Any]:
        detail = await self.get_session(session_id, organisation_id, user_id)
        return {
            "kind": "intqaflow-guided-session",
            "version": 1,
            "exportedAt": datetime.now(UTC).isoformat(),
            "session": detail.model_dump(mode="json"),
        }

    async def export_csv(
        self, session_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> str:
        detail = await self.get_session(session_id, organisation_id, user_id)
        participants = {item.id: item.name for item in detail.participants}
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(
            ["session_title", "participant", "scope", "type", "depth", "question", "answer", "returns_to"]
        )

        def write_question(question: GuidedFlowQuestion, depth: int, return_to: str) -> None:
            for answer in question.answers or [None]:
                participant = participants.get(answer.participant_id, "") if answer else ""
                row = [
                    detail.title,
                    participant,
                    question.scope.value,
                    "follow_up" if depth else "question",
                    depth,
                    question.text,
                    answer.body if answer else "",
                    return_to,
                ]
                writer.writerow(
                    [
                        _spreadsheet_safe_csv_cell(cell)
                        if isinstance(cell, str)
                        else cell
                        for cell in row
                    ]
                )
            for child in question.follow_ups:
                write_question(child, depth + 1, "previous path" if depth else "main path")

        for root in detail.questions:
            write_question(root, 0, "")
        return output.getvalue()

    async def import_legacy(
        self,
        organisation_id: UUID,
        user_id: UUID,
        payload: dict[str, Any] | list[Any],
    ) -> LegacyImportResponse:
        await self.permissions.actor(user_id, organisation_id)
        warnings: list[str] = []
        source = {"flow": payload} if isinstance(payload, list) else payload
        meta = source.get("meta") if isinstance(source.get("meta"), dict) else {}
        session = GuidedSession(
            organisation_id=organisation_id,
            created_by=user_id,
            title=str(meta.get("caseTitle") or "Imported Interaction QA Flow"),
            owner_text=str(meta.get("interviewer") or "") or None,
            context_reference=str(meta.get("interviewee") or "") or None,
            visibility=GuidedSessionVisibility.PRIVATE,
            status=GuidedSessionStatus.DRAFT,
            revision=1,
        )
        await self.guided.add(session)
        participants_payload = source.get("participants")
        if not isinstance(participants_payload, list) or not participants_payload:
            participants_payload = [{"id": "participant-1", "name": "Participant 1"}]
            warnings.append("No participant list was present; Participant 1 was created.")
        participant_map: dict[str, GuidedParticipant] = {}
        for index, item in enumerate(participants_payload):
            if not isinstance(item, dict):
                warnings.append(f"Participant {index + 1} was not an object and was skipped.")
                continue
            participant = GuidedParticipant(
                organisation_id=organisation_id,
                session_id=session.id,
                name=str(item.get("name") or f"Participant {index + 1}"),
                sort_order=index,
            )
            await self.guided.add(participant)
            participant_map[str(item.get("id") or f"participant-{index + 1}")] = participant
        if not participant_map:
            raise ConflictError("Legacy flow did not contain any usable participants")
        flow = source.get("flow")
        if not isinstance(flow, list):
            flow = []
            warnings.append("No flow array was present.")
        for index, node in enumerate(flow):
            if isinstance(node, dict):
                await self._import_legacy_node(
                    session, node, participant_map, user_id, index, None, warnings
                )
            else:
                warnings.append(f"Flow item {index + 1} was not an object and was skipped.")
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_LEGACY_IMPORT,
            "guided_session",
            session.id,
            {"warning_count": len(warnings), "participant_count": len(participant_map)},
        )
        await self.session.commit()
        detail = await self.get_session(session.id, organisation_id, user_id)
        return LegacyImportResponse(session=detail, warnings=warnings)

    async def create_template(
        self,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedTemplateCreate,
    ) -> GuidedTemplateResponse:
        await self.permissions.actor(user_id, organisation_id)
        await self._validate_structure(data.department_id, data.team_id, organisation_id)
        template = GuidedTemplate(
            organisation_id=organisation_id,
            created_by=user_id,
            name=data.name,
            description=data.description,
            department_id=data.department_id,
            team_id=data.team_id,
            status=GuidedTemplateStatus.ACTIVE,
            current_version=1,
        )
        try:
            await self.guided.add(template)
            version = await self._create_template_version(template, user_id, 1, data.questions)
            await self._audit(
                organisation_id,
                user_id,
                AuditAction.GUIDED_TEMPLATE_CREATED,
                "guided_template",
                template.id,
            )
            await self._audit(
                organisation_id,
                user_id,
                AuditAction.GUIDED_TEMPLATE_VERSION_CREATED,
                "guided_template_version",
                version.id,
                {"template_id": str(template.id), "version_number": 1},
            )
            await self.session.commit()
        except IntegrityError as error:
            await self.session.rollback()
            raise ConflictError("A template with this name already exists") from error
        return await self.get_template(template.id, organisation_id, user_id)

    async def list_templates(
        self, organisation_id: UUID, user_id: UUID
    ) -> list[GuidedTemplateResponse]:
        await self.permissions.actor(user_id, organisation_id)
        templates = await self.guided.templates(organisation_id)
        if not templates:
            default = await self.create_template(
                organisation_id,
                user_id,
                GuidedTemplateCreate(
                    name="General Interaction QA",
                    description="Default prepared path for a structured conversation.",
                    questions=[
                        GuidedTemplateQuestionInput(text=text, order_index=index)
                        for index, text in enumerate(
                            (
                                "What is the main topic or request?",
                                "Who is affected or involved?",
                                "What information is already known?",
                                "What follow-up is needed next?",
                            )
                        )
                    ],
                ),
            )
            return [default]
        return [
            await self._template_response(item)
            for item in templates
        ]

    async def export_templates(
        self, organisation_id: UUID, user_id: UUID
    ) -> dict[str, Any]:
        templates = await self.list_templates(organisation_id, user_id)
        return {
            "kind": "intqaflow-guided-templates",
            "version": 1,
            "exportedAt": datetime.now(UTC).isoformat(),
            "templates": [item.model_dump(mode="json") for item in templates],
        }

    async def import_templates(
        self,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedTemplateImportRequest,
    ) -> list[GuidedTemplateResponse]:
        source = data.payload
        records = source if isinstance(source, list) else source.get("templates", [])
        if not isinstance(records, list):
            raise ConflictError("Template import must contain a templates array")
        imported: list[GuidedTemplateResponse] = []
        for index, record in enumerate(records):
            if not isinstance(record, dict):
                continue
            questions: list[GuidedTemplateQuestionInput] = []
            version = record.get("version") if isinstance(record.get("version"), dict) else None
            raw_questions = version.get("questions", []) if version else record.get("flow", record.get("questions", []))
            if isinstance(raw_questions, list):
                self._normalize_template_questions(raw_questions, questions)
            if not questions:
                continue
            name = str(record.get("name") or f"Imported template {index + 1}")
            existing = next(
                (
                    item
                    for item in await self.guided.templates(organisation_id)
                    if item.name.casefold() == name.casefold()
                ),
                None,
            )
            if existing:
                imported.append(
                    await self.version_template(
                        existing.id,
                        organisation_id,
                        user_id,
                        GuidedTemplateVersionCreate(questions=questions),
                    )
                )
            else:
                imported.append(
                    await self.create_template(
                        organisation_id,
                        user_id,
                        GuidedTemplateCreate(
                            name=name,
                            description=record.get("description"),
                            questions=questions,
                        ),
                    )
                )
        if not imported:
            raise ConflictError("No usable templates were found")
        return imported

    def _normalize_template_questions(
        self,
        nodes: list[Any],
        output: list[GuidedTemplateQuestionInput],
        parent_reference: str | None = None,
    ) -> None:
        for index, node in enumerate(nodes):
            if isinstance(node, str):
                output.append(GuidedTemplateQuestionInput(text=node, order_index=index))
                continue
            if not isinstance(node, dict):
                continue
            reference = str(node.get("id") or uuid4())
            output.append(
                GuidedTemplateQuestionInput(
                    text=str(node.get("text") or node.get("question") or "Untitled question"),
                    scope=GuidedQuestionScope.PARTICIPANT
                    if node.get("scope") == "participant"
                    else GuidedQuestionScope.SHARED,
                    participant_reference=node.get("participant_reference")
                    or node.get("participantId"),
                    order_index=int(node.get("order_index", index)),
                    reference=reference,
                    parent_reference=parent_reference
                    or node.get("parent_template_question_id"),
                )
            )
            answers = node.get("answers") if isinstance(node.get("answers"), dict) else {}
            for answer in answers.values():
                if isinstance(answer, dict) and isinstance(answer.get("branches"), list):
                    self._normalize_template_questions(answer["branches"], output, reference)

    async def get_template(
        self, template_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> GuidedTemplateResponse:
        await self.permissions.actor(user_id, organisation_id)
        template = await self.guided.template(template_id, organisation_id)
        if not template:
            raise NotFoundError("Guided template not found")
        return await self._template_response(template)

    async def update_template(
        self,
        template_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedTemplateUpdate,
    ) -> GuidedTemplateResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        template = await self.guided.template(template_id, organisation_id)
        if not template:
            raise NotFoundError("Guided template not found")
        if actor.id != template.created_by and not await self.permissions.is_organisation_admin(actor):
            raise PermissionDeniedError("Only the template owner or an admin can update it")
        changes = data.model_dump(exclude_unset=True)
        await self._validate_structure(
            changes.get("department_id", template.department_id),
            changes.get("team_id", template.team_id),
            organisation_id,
        )
        for field, value in changes.items():
            setattr(template, field, value)
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_TEMPLATE_UPDATED,
            "guided_template",
            template.id,
        )
        await self.session.commit()
        return await self._template_response(template)

    async def version_template(
        self,
        template_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
        data: GuidedTemplateVersionCreate,
    ) -> GuidedTemplateResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        template = await self.guided.template(template_id, organisation_id)
        if not template:
            raise NotFoundError("Guided template not found")
        if actor.id != template.created_by and not await self.permissions.is_organisation_admin(actor):
            raise PermissionDeniedError("Only the template owner or an admin can version it")
        template.current_version += 1
        version = await self._create_template_version(
            template, user_id, template.current_version, data.questions
        )
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_TEMPLATE_VERSION_CREATED,
            "guided_template_version",
            version.id,
            {"template_id": str(template.id), "version_number": template.current_version},
        )
        await self.session.commit()
        return await self._template_response(template)

    async def archive_template(
        self, template_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> GuidedTemplateResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        template = await self.guided.template(template_id, organisation_id)
        if not template:
            raise NotFoundError("Guided template not found")
        if actor.id != template.created_by and not await self.permissions.is_organisation_admin(actor):
            raise PermissionDeniedError("Only the template owner or an admin can archive it")
        template.status = GuidedTemplateStatus.ARCHIVED
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_TEMPLATE_ARCHIVED,
            "guided_template",
            template.id,
        )
        await self.session.commit()
        return await self._template_response(template)

    async def restore_template(
        self, template_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> GuidedTemplateResponse:
        actor = await self.permissions.actor(user_id, organisation_id)
        template = await self.guided.template(template_id, organisation_id)
        if not template:
            raise NotFoundError("Guided template not found")
        if actor.id != template.created_by and not await self.permissions.is_organisation_admin(actor):
            raise PermissionDeniedError("Only the template owner or an admin can restore it")
        if template.status != GuidedTemplateStatus.ARCHIVED:
            raise ConflictError("Only archived templates can be restored")
        template.status = GuidedTemplateStatus.ACTIVE
        await self._audit(
            organisation_id,
            user_id,
            AuditAction.GUIDED_TEMPLATE_RESTORED,
            "guided_template",
            template.id,
        )
        await self.session.commit()
        return await self._template_response(template)

    async def duplicate_template(
        self, template_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> GuidedTemplateResponse:
        source = await self.get_template(template_id, organisation_id, user_id)
        questions = [
            GuidedTemplateQuestionInput(
                text=item.text,
                scope=item.scope,
                participant_reference=item.participant_reference,
                order_index=item.order_index,
                reference=str(item.id),
                parent_reference=str(item.parent_template_question_id)
                if item.parent_template_question_id
                else None,
            )
            for item in (source.version.questions if source.version else [])
        ]
        return await self.create_template(
            organisation_id,
            user_id,
            GuidedTemplateCreate(
                name=f"{source.name} copy",
                description=source.description,
                department_id=source.department_id,
                team_id=source.team_id,
                questions=questions,
            ),
        )

    async def _instantiate_template(
        self, session: GuidedSession, version: GuidedTemplateVersion, user_id: UUID
    ) -> None:
        templates = await self.guided.template_questions(version.id, session.organisation_id)
        references = sorted(
            {item.participant_reference for item in templates if item.participant_reference}
        )
        if not references:
            references = ["Participant 1"]
        participants: dict[str, GuidedParticipant] = {}
        for index, name in enumerate(references):
            participant = GuidedParticipant(
                organisation_id=session.organisation_id,
                session_id=session.id,
                name=name,
                sort_order=index,
            )
            await self.guided.add(participant)
            participants[name] = participant
        question_map: dict[UUID, GuidedQuestion] = {}
        pending = list(templates)
        while pending:
            progressed = False
            for item in pending[:]:
                if item.parent_template_question_id and item.parent_template_question_id not in question_map:
                    continue
                target = participants.get(item.participant_reference or "")
                if item.parent_template_question_id:
                    parent = question_map[item.parent_template_question_id]
                    branch_participant = target or next(iter(participants.values()))
                    if parent.scope == GuidedQuestionScope.PARTICIPANT and parent.target_participant_id:
                        branch_participant = next(
                            value for value in participants.values() if value.id == parent.target_participant_id
                        )
                    answer = await self.guided.answer_for_question(
                        parent.id, branch_participant.id, session.organisation_id
                    )
                    if answer is None:
                        answer = GuidedAnswer(
                            organisation_id=session.organisation_id,
                            session_id=session.id,
                            question_id=parent.id,
                            participant_id=branch_participant.id,
                            body="",
                            branches_collapsed=False,
                        )
                        await self.guided.add(answer)
                    question = GuidedQuestion(
                        organisation_id=session.organisation_id,
                        session_id=session.id,
                        template_question_id=item.id,
                        created_by=user_id,
                        text=item.text,
                        scope=GuidedQuestionScope.PARTICIPANT,
                        target_participant_id=branch_participant.id,
                        source=GuidedQuestionSource.FOLLOW_UP,
                        branch_order_index=item.order_index,
                        triggering_answer_id=answer.id,
                    )
                else:
                    question = GuidedQuestion(
                        organisation_id=session.organisation_id,
                        session_id=session.id,
                        template_question_id=item.id,
                        created_by=user_id,
                        text=item.text,
                        scope=item.scope,
                        target_participant_id=target.id if target else None,
                        source=GuidedQuestionSource.TEMPLATE,
                        main_order_index=item.order_index,
                    )
                await self.guided.add(question)
                question_map[item.id] = question
                pending.remove(item)
                progressed = True
            if not progressed:
                raise ConflictError("Template contains an invalid follow-up cycle")

    async def _create_template_version(
        self,
        template: GuidedTemplate,
        user_id: UUID,
        number: int,
        questions: list[GuidedTemplateQuestionInput],
    ) -> GuidedTemplateVersion:
        version = GuidedTemplateVersion(
            organisation_id=template.organisation_id,
            template_id=template.id,
            version_number=number,
            created_by=user_id,
        )
        await self.guided.add(version)
        references: dict[str, GuidedTemplateQuestion] = {}
        pending = list(questions)
        while pending:
            progressed = False
            for item in pending[:]:
                if item.parent_reference and item.parent_reference not in references:
                    continue
                question = GuidedTemplateQuestion(
                    organisation_id=template.organisation_id,
                    template_version_id=version.id,
                    text=item.text,
                    scope=item.scope,
                    participant_reference=item.participant_reference,
                    order_index=item.order_index,
                    parent_template_question_id=(
                        references[item.parent_reference].id if item.parent_reference else None
                    ),
                )
                await self.guided.add(question)
                if item.reference:
                    references[item.reference] = question
                pending.remove(item)
                progressed = True
            if not progressed:
                raise ConflictError("Template question has an unknown parent reference")
        return version

    async def _template_response(self, template: GuidedTemplate) -> GuidedTemplateResponse:
        await self.session.refresh(template)
        version = await self.guided.current_template_version(template)
        version_response = None
        if version:
            questions = await self.guided.template_questions(version.id, template.organisation_id)
            version_response = GuidedTemplateVersionResponse.model_validate(
                {
                    **version.__dict__,
                    "questions": [GuidedTemplateQuestionResponse.model_validate(item) for item in questions],
                }
            )
        return GuidedTemplateResponse.model_validate(
            {**template.__dict__, "version": version_response}
        )

    async def _import_legacy_node(
        self,
        session: GuidedSession,
        node: dict[str, Any],
        participants: dict[str, GuidedParticipant],
        user_id: UUID,
        order: int,
        triggering_answer: GuidedAnswer | None,
        warnings: list[str],
    ) -> None:
        scope = (
            GuidedQuestionScope.PARTICIPANT
            if node.get("scope") == "participant" or triggering_answer
            else GuidedQuestionScope.SHARED
        )
        target = participants.get(str(node.get("participantId"))) if scope == GuidedQuestionScope.PARTICIPANT else None
        if triggering_answer:
            target = next(
                item for item in participants.values() if item.id == triggering_answer.participant_id
            )
        if scope == GuidedQuestionScope.PARTICIPANT and target is None:
            target = next(iter(participants.values()))
            warnings.append(f"Question '{node.get('question', 'Untitled')}' had an unknown participant; it was assigned to {target.name}.")
        question = GuidedQuestion(
            organisation_id=session.organisation_id,
            session_id=session.id,
            created_by=user_id,
            text=str(node.get("question") or "Untitled question"),
            scope=scope,
            target_participant_id=target.id if target else None,
            source=GuidedQuestionSource.FOLLOW_UP if triggering_answer else GuidedQuestionSource.MANUAL,
            main_order_index=None if triggering_answer else order,
            branch_order_index=order if triggering_answer else None,
            triggering_answer_id=triggering_answer.id if triggering_answer else None,
        )
        await self.guided.add(question)
        raw_answers = node.get("answers") if isinstance(node.get("answers"), dict) else None
        if raw_answers is None:
            participant_key = str(node.get("participantId") or next(iter(participants)))
            raw_answers = {
                participant_key: {
                    "answer": node.get("answer", ""),
                    "branches": node.get("branches", []),
                    "branchesCollapsed": node.get("branchesCollapsed", False),
                }
            }
        for participant_key, record in raw_answers.items():
            participant = participants.get(str(participant_key))
            if not participant or not isinstance(record, dict):
                warnings.append(f"An answer for '{question.text}' had an unknown participant and was skipped.")
                continue
            if target and participant.id != target.id:
                continue
            answer = GuidedAnswer(
                organisation_id=session.organisation_id,
                session_id=session.id,
                question_id=question.id,
                participant_id=participant.id,
                answered_by_user_id=user_id,
                body=str(record.get("answer") or ""),
                branches_collapsed=bool(record.get("branchesCollapsed")),
            )
            await self.guided.add(answer)
            branches = record.get("branches") if isinstance(record.get("branches"), list) else []
            for branch_order, branch in enumerate(branches):
                if isinstance(branch, dict):
                    await self._import_legacy_node(
                        session,
                        branch,
                        participants,
                        user_id,
                        branch_order,
                        answer,
                        warnings,
                    )

    def _build_flow(
        self,
        questions: list[GuidedQuestion],
        answers: list[GuidedAnswer],
        participant_id: UUID | None,
        view_mode: GuidedViewMode,
    ) -> list[GuidedFlowQuestion]:
        answers_by_question: dict[UUID, list[GuidedAnswer]] = {}
        for answer in answers:
            if participant_id is None or answer.participant_id == participant_id:
                answers_by_question.setdefault(answer.question_id, []).append(answer)
        children: dict[UUID, list[GuidedQuestion]] = {}
        roots: list[GuidedQuestion] = []
        for question in questions:
            if question.triggering_answer_id:
                children.setdefault(question.triggering_answer_id, []).append(question)
            else:
                roots.append(question)

        def visible(question: GuidedQuestion) -> bool:
            if question.scope == GuidedQuestionScope.SHARED:
                return view_mode != GuidedViewMode.PARTICIPANT_ONLY
            return (
                view_mode != GuidedViewMode.SHARED_ONLY
                and (participant_id is None or question.target_participant_id == participant_id)
            )

        def build(question: GuidedQuestion) -> GuidedFlowQuestion:
            question_answers = answers_by_question.get(question.id, [])
            follow_ups = [
                build(child)
                for answer in question_answers
                for child in children.get(answer.id, [])
                if visible(child)
            ]
            return GuidedFlowQuestion.model_validate(
                {
                    **question.__dict__,
                    "answers": [GuidedAnswerResponse.model_validate(item) for item in question_answers],
                    "follow_ups": follow_ups,
                }
            )

        return [build(question) for question in roots if visible(question)]

    async def _validate_structure(
        self,
        department_id: UUID | None,
        team_id: UUID | None,
        organisation_id: UUID,
        *,
        require_department: bool = False,
    ) -> None:
        if require_department and department_id is None:
            raise ConflictError("Department-visible sessions require a department")
        if department_id and not await self.departments.get_for_organisation(
            department_id, organisation_id
        ):
            raise NotFoundError("Department not found in this organisation")
        if team_id:
            row = await self.teams.get(team_id, organisation_id)
            if not row:
                raise NotFoundError("Team not found in this organisation")
            team, _ = row
            if team.department_id and department_id and team.department_id != department_id:
                raise ConflictError("Team does not belong to the selected department")

    async def _session(self, session_id: UUID, organisation_id: UUID) -> GuidedSession:
        session = await self.guided.guided_session(session_id, organisation_id)
        if not session:
            raise NotFoundError("Guided session not found")
        return session

    async def _owned_session(
        self, session_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> GuidedSession:
        actor = await self.permissions.actor(user_id, organisation_id)
        session = await self._session(session_id, organisation_id)
        if actor.id != session.created_by and (
            session.visibility == GuidedSessionVisibility.PRIVATE
            or not await self.permissions.is_organisation_admin(actor)
        ):
            raise PermissionDeniedError("Only the session owner can change a private session")
        return session

    async def _require_view(self, actor, session: GuidedSession) -> None:
        if actor.id == session.created_by:
            return
        if (
            await self.permissions.is_organisation_admin(actor)
            and session.visibility != GuidedSessionVisibility.PRIVATE
        ):
            return
        if session.visibility == GuidedSessionVisibility.ORGANISATION:
            return
        if (
            session.visibility == GuidedSessionVisibility.DEPARTMENT
            and session.department_id is not None
            and actor.department_id is not None
            and actor.department_id == session.department_id
        ):
            return
        if session.visibility == GuidedSessionVisibility.TEAM:
            team_ids = await self.teams.team_ids_for_user(actor.id, actor.organisation_id)
            if session.team_id in team_ids:
                return
        raise PermissionDeniedError("You do not have permission to view this Guided session")

    async def _participant(self, entity_id: UUID, organisation_id: UUID) -> GuidedParticipant:
        participant = await self.guided.participant(entity_id, organisation_id)
        if not participant:
            raise NotFoundError("Guided participant not found")
        return participant

    async def _question(self, entity_id: UUID, organisation_id: UUID) -> GuidedQuestion:
        question = await self.guided.question(entity_id, organisation_id)
        if not question:
            raise NotFoundError("Guided question not found")
        return question

    async def _answer(self, entity_id: UUID, organisation_id: UUID) -> GuidedAnswer:
        answer = await self.guided.answer(entity_id, organisation_id)
        if not answer:
            raise NotFoundError("Guided answer not found")
        return answer

    async def _save_revision(
        self, session: GuidedSession, user_id: UUID, change: str
    ) -> None:
        session.revision += 1
        await self.guided.add(
            GuidedSessionRevision(
                organisation_id=session.organisation_id,
                session_id=session.id,
                revision_number=session.revision,
                saved_by=user_id,
                summary={"change": change},
            )
        )

    async def _audit(
        self,
        organisation_id: UUID,
        actor_id: UUID,
        action: AuditAction,
        entity_type: str,
        entity_id: UUID,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        await self.governance.add(
            AuditEvent(
                organisation_id=organisation_id,
                actor_id=actor_id,
                action=action.value,
                entity_type=entity_type,
                entity_id=entity_id,
                event_metadata=metadata,
            )
        )