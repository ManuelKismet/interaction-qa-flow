from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.answer import Answer, AnswerStatus
from app.models.department import Department
from app.models.duplicate_suggestion import (
    DuplicateSuggestion,
    DuplicateSuggestionStatus,
)
from app.models.question import Question
from app.models.team import Team


class CanonicalRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def question(
        self,
        question_id: UUID,
        organisation_id: UUID,
        *,
        for_update: bool = False,
    ) -> Question | None:
        statement = select(Question).where(
            Question.id == question_id,
            Question.organisation_id == organisation_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self.session.execute(statement)).scalar_one_or_none()

    async def descendants(
        self,
        question_ids: set[UUID],
        organisation_id: UUID,
    ) -> list[Question]:
        if not question_ids:
            return []
        return list(
            await self.session.scalars(
                select(Question)
                .where(
                    Question.organisation_id == organisation_id,
                    Question.canonical_question_id.in_(question_ids),
                )
                .with_for_update()
            )
        )

    async def answer(
        self,
        answer_id: UUID,
        organisation_id: UUID,
    ) -> Answer | None:
        return (
            await self.session.execute(
                select(Answer).where(
                    Answer.id == answer_id,
                    Answer.organisation_id == organisation_id,
                )
            )
        ).scalar_one_or_none()

    async def reusable_answers(
        self,
        question_ids: set[UUID],
        organisation_id: UUID,
    ) -> list[Answer]:
        return list(
            await self.session.scalars(
                select(Answer).where(
                    Answer.organisation_id == organisation_id,
                    Answer.question_id.in_(question_ids),
                    Answer.status.in_(
                        [AnswerStatus.VERIFIED, AnswerStatus.COMMUNITY]
                    ),
                )
            )
        )

    async def aliases(
        self,
        canonical_question_id: UUID,
        organisation_id: UUID,
        limit: int = 5,
    ) -> list[Question]:
        return list(
            await self.session.scalars(
                select(Question)
                .where(
                    Question.organisation_id == organisation_id,
                    Question.canonical_question_id == canonical_question_id,
                )
                .order_by(Question.updated_at.desc())
                .limit(limit)
            )
        )

    async def add(self, entity) -> None:
        self.session.add(entity)
        await self.session.flush()

    async def suggestion(
        self,
        suggestion_id: UUID,
        organisation_id: UUID,
        *,
        for_update: bool = False,
    ) -> DuplicateSuggestion | None:
        statement = select(DuplicateSuggestion).where(
            DuplicateSuggestion.id == suggestion_id,
            DuplicateSuggestion.organisation_id == organisation_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self.session.execute(statement)).scalar_one_or_none()

    async def suggestion_rows(
        self,
        organisation_id: UUID,
        department_ids: list[UUID] | None,
        status: DuplicateSuggestionStatus,
    ) -> list[tuple[DuplicateSuggestion, Question, Question, Department | None]]:
        target = aliased(Question, name="suggested_canonical")
        effective_department_id = func.coalesce(
            Question.department_id, Team.department_id
        )
        statement = (
            select(DuplicateSuggestion, Question, target, Department)
            .join(Question, Question.id == DuplicateSuggestion.question_id)
            .join(target, target.id == DuplicateSuggestion.suggested_canonical_question_id)
            .outerjoin(Team, Team.id == Question.team_id)
            .outerjoin(Department, Department.id == effective_department_id)
            .where(
                DuplicateSuggestion.organisation_id == organisation_id,
                DuplicateSuggestion.status == status,
                Question.organisation_id == organisation_id,
                target.organisation_id == organisation_id,
            )
        )
        if department_ids is not None:
            statement = statement.where(effective_department_id.in_(department_ids))
        rows = await self.session.execute(
            statement.order_by(DuplicateSuggestion.created_at.asc())
        )
        return [
            (row.DuplicateSuggestion, row.Question, row[2], row.Department)
            for row in rows
        ]

    async def related_open_suggestions(
        self,
        organisation_id: UUID,
        question_ids: set[UUID],
    ) -> list[DuplicateSuggestion]:
        return list(
            await self.session.scalars(
                select(DuplicateSuggestion).where(
                    DuplicateSuggestion.organisation_id == organisation_id,
                    DuplicateSuggestion.status == DuplicateSuggestionStatus.OPEN,
                    or_(
                        DuplicateSuggestion.question_id.in_(question_ids),
                        DuplicateSuggestion.suggested_canonical_question_id.in_(
                            question_ids
                        ),
                    ),
                )
            )
        )