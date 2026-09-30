from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.guided import (
    GuidedAnswer,
    GuidedParticipant,
    GuidedQuestion,
    GuidedSession,
    GuidedSessionRevision,
    GuidedSessionStatus,
    GuidedSessionVisibility,
    GuidedTemplate,
    GuidedTemplateQuestion,
    GuidedTemplateVersion,
    KnowledgeProposal,
)


class GuidedRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, entity) -> None:
        self.session.add(entity)
        await self.session.flush()

    async def guided_session(self, entity_id: UUID, organisation_id: UUID) -> GuidedSession | None:
        return await self.session.scalar(
            select(GuidedSession).where(
                GuidedSession.id == entity_id,
                GuidedSession.organisation_id == organisation_id,
            )
        )

    async def visible_sessions(
        self,
        organisation_id: UUID,
        user_id: UUID,
        department_id: UUID | None,
        team_ids: list[UUID],
        is_admin: bool,
        status: GuidedSessionStatus | None = None,
    ) -> list[GuidedSession]:
        visibility = [
            GuidedSession.created_by == user_id,
            GuidedSession.visibility == GuidedSessionVisibility.ORGANISATION,
        ]
        if department_id:
            visibility.append(
                and_(
                    GuidedSession.visibility == GuidedSessionVisibility.DEPARTMENT,
                    GuidedSession.department_id == department_id,
                )
            )
        if team_ids:
            visibility.append(
                and_(
                    GuidedSession.visibility == GuidedSessionVisibility.TEAM,
                    GuidedSession.team_id.in_(team_ids),
                )
            )
        statement = select(GuidedSession).where(GuidedSession.organisation_id == organisation_id)
        if not is_admin:
            statement = statement.where(or_(*visibility))
        if status:
            statement = statement.where(GuidedSession.status == status)
        rows = await self.session.scalars(statement.order_by(GuidedSession.updated_at.desc()))
        return list(rows)

    async def participants(self, session_id: UUID, organisation_id: UUID) -> list[GuidedParticipant]:
        rows = await self.session.scalars(
            select(GuidedParticipant)
            .where(
                GuidedParticipant.session_id == session_id,
                GuidedParticipant.organisation_id == organisation_id,
            )
            .order_by(GuidedParticipant.sort_order, GuidedParticipant.created_at)
        )
        return list(rows)

    async def participant(self, entity_id: UUID, organisation_id: UUID) -> GuidedParticipant | None:
        return await self.session.scalar(
            select(GuidedParticipant).where(
                GuidedParticipant.id == entity_id,
                GuidedParticipant.organisation_id == organisation_id,
            )
        )

    async def questions(self, session_id: UUID, organisation_id: UUID, include_deleted: bool = False) -> list[GuidedQuestion]:
        statement = select(GuidedQuestion).where(
            GuidedQuestion.session_id == session_id,
            GuidedQuestion.organisation_id == organisation_id,
        )
        if not include_deleted:
            statement = statement.where(GuidedQuestion.deleted_at.is_(None))
        rows = await self.session.scalars(
            statement.order_by(
                GuidedQuestion.main_order_index.asc().nullslast(),
                GuidedQuestion.branch_order_index.asc().nullslast(),
                GuidedQuestion.created_at,
            )
        )
        return list(rows)

    async def question(self, entity_id: UUID, organisation_id: UUID) -> GuidedQuestion | None:
        return await self.session.scalar(
            select(GuidedQuestion).where(
                GuidedQuestion.id == entity_id,
                GuidedQuestion.organisation_id == organisation_id,
            )
        )

    async def answers(self, session_id: UUID, organisation_id: UUID) -> list[GuidedAnswer]:
        rows = await self.session.scalars(
            select(GuidedAnswer).where(
                GuidedAnswer.session_id == session_id,
                GuidedAnswer.organisation_id == organisation_id,
            )
        )
        return list(rows)

    async def answer(self, entity_id: UUID, organisation_id: UUID) -> GuidedAnswer | None:
        return await self.session.scalar(
            select(GuidedAnswer).where(
                GuidedAnswer.id == entity_id,
                GuidedAnswer.organisation_id == organisation_id,
            )
        )

    async def answer_for_question(self, question_id: UUID, participant_id: UUID, organisation_id: UUID) -> GuidedAnswer | None:
        return await self.session.scalar(
            select(GuidedAnswer).where(
                GuidedAnswer.question_id == question_id,
                GuidedAnswer.participant_id == participant_id,
                GuidedAnswer.organisation_id == organisation_id,
            )
        )

    async def templates(self, organisation_id: UUID) -> list[GuidedTemplate]:
        rows = await self.session.scalars(
            select(GuidedTemplate)
            .where(GuidedTemplate.organisation_id == organisation_id)
            .order_by(GuidedTemplate.name)
        )
        return list(rows)

    async def template(self, entity_id: UUID, organisation_id: UUID) -> GuidedTemplate | None:
        return await self.session.scalar(
            select(GuidedTemplate).where(
                GuidedTemplate.id == entity_id,
                GuidedTemplate.organisation_id == organisation_id,
            )
        )

    async def template_version(self, entity_id: UUID, organisation_id: UUID) -> GuidedTemplateVersion | None:
        return await self.session.scalar(
            select(GuidedTemplateVersion).where(
                GuidedTemplateVersion.id == entity_id,
                GuidedTemplateVersion.organisation_id == organisation_id,
            )
        )

    async def current_template_version(self, template: GuidedTemplate) -> GuidedTemplateVersion | None:
        return await self.session.scalar(
            select(GuidedTemplateVersion).where(
                GuidedTemplateVersion.template_id == template.id,
                GuidedTemplateVersion.organisation_id == template.organisation_id,
                GuidedTemplateVersion.version_number == template.current_version,
            )
        )

    async def template_questions(self, version_id: UUID, organisation_id: UUID) -> list[GuidedTemplateQuestion]:
        rows = await self.session.scalars(
            select(GuidedTemplateQuestion)
            .where(
                GuidedTemplateQuestion.template_version_id == version_id,
                GuidedTemplateQuestion.organisation_id == organisation_id,
            )
            .order_by(GuidedTemplateQuestion.order_index, GuidedTemplateQuestion.created_at)
        )
        return list(rows)

    async def revisions(self, session_id: UUID, organisation_id: UUID) -> list[GuidedSessionRevision]:
        rows = await self.session.scalars(
            select(GuidedSessionRevision)
            .where(
                GuidedSessionRevision.session_id == session_id,
                GuidedSessionRevision.organisation_id == organisation_id,
            )
            .order_by(GuidedSessionRevision.revision_number.desc())
            .limit(20)
        )
        return list(rows)

    async def proposals(self, organisation_id: UUID) -> list[KnowledgeProposal]:
        rows = await self.session.scalars(
            select(KnowledgeProposal)
            .where(KnowledgeProposal.organisation_id == organisation_id)
            .order_by(KnowledgeProposal.created_at.desc())
        )
        return list(rows)

    async def proposal(self, entity_id: UUID, organisation_id: UUID) -> KnowledgeProposal | None:
        return await self.session.scalar(
            select(KnowledgeProposal).where(
                KnowledgeProposal.id == entity_id,
                KnowledgeProposal.organisation_id == organisation_id,
            )
        )

    async def delete(self, entity) -> None:
        await self.session.delete(entity)