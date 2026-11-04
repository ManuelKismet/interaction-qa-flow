from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.answer import Answer, AnswerStatus
from app.models.comment import Comment
from app.models.department import Department
from app.models.question_change_request import (
    ChangeRequestStatus,
    QuestionChangeRequest,
)
from app.models.question import Question
from app.models.question_version import QuestionVersion
from app.models.team import Team
from app.models.user import User
from app.services.permissions import PermissionService


class QuestionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, question: Question) -> Question:
        self.session.add(question)
        await self.session.flush()
        return question

    async def list_for_organisation(
        self,
        organisation_id: UUID,
        offset: int,
        limit: int,
        *,
        actor: User,
        status=None,
        department_id: UUID | None = None,
        team_id: UUID | None = None,
        author_id: UUID | None = None,
    ) -> list[tuple[Question, Department | None, Team | None, int]]:
        answer_count = (
            select(func.count(Answer.id))
            .where(Answer.question_id == Question.id)
            .correlate(Question)
            .scalar_subquery()
        )
        statement = (
            select(Question, Department, Team, answer_count.label("answer_count"))
            .outerjoin(
                Department,
                (Department.id == Question.department_id)
                & (Department.organisation_id == organisation_id),
            )
            .outerjoin(
                Team,
                (Team.id == Question.team_id)
                & (Team.organisation_id == organisation_id),
            )
            .where(Question.organisation_id == organisation_id)
        )
        if status is not None:
            statement = statement.where(Question.status == status)
        if department_id is not None:
            statement = statement.where(Question.department_id == department_id)
        if team_id is not None:
            statement = statement.where(Question.team_id == team_id)
        if author_id is not None:
            statement = statement.where(Question.author_id == author_id)
        statement = statement.where(PermissionService.question_visibility_clause(actor))

        result = await self.session.execute(
            statement.order_by(Question.created_at.desc()).offset(offset).limit(limit)
        )
        return [
            (row.Question, row.Department, row.Team, row.answer_count)
            for row in result
        ]

    async def get_for_organisation(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> Question | None:
        result = await self.session.execute(
            select(Question).where(
                Question.id == question_id,
                Question.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def get_detail_for_organisation(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> tuple[Question, User, Department | None, Team | None] | None:
        result = await self.session.execute(
            select(Question, User, Department, Team)
            .join(
                User,
                (User.id == Question.author_id)
                & (User.organisation_id == organisation_id),
            )
            .outerjoin(
                Team,
                (Team.id == Question.team_id)
                & (Team.organisation_id == organisation_id),
            )
            .outerjoin(
                Department,
                (Department.id == Question.department_id)
                & (Department.organisation_id == organisation_id),
            )
            .where(
                Question.id == question_id,
                Question.organisation_id == organisation_id,
            )
        )
        row = result.one_or_none()
        return (row.Question, row.User, row.Department, row.Team) if row else None

    async def comment_count(self, question_id: UUID, organisation_id: UUID) -> int:
        result = await self.session.scalar(
            select(func.count(Comment.id)).where(
                Comment.question_id == question_id,
                Comment.organisation_id == organisation_id,
            )
        )
        return result or 0

    async def list_aliases(
        self,
        canonical_question_id: UUID,
        organisation_id: UUID,
        limit: int,
        actor: User,
    ) -> list[Question]:
        return list(
            await self.session.scalars(
                select(Question)
                .where(
                    Question.organisation_id == organisation_id,
                    Question.canonical_question_id == canonical_question_id,
                    PermissionService.question_visibility_clause(actor),
                )
                .order_by(Question.updated_at.desc())
                .limit(limit)
            )
        )

    async def contribution_count(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> int:
        answer_count = await self.session.scalar(
            select(func.count(Answer.id)).where(
                Answer.question_id == question_id,
                Answer.organisation_id == organisation_id,
            )
        )
        comment_count = await self.session.scalar(
            select(func.count(Comment.id)).where(
                Comment.question_id == question_id,
                Comment.organisation_id == organisation_id,
            )
        )
        return int(answer_count or 0) + int(comment_count or 0)

    async def has_verified_answer(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> bool:
        return bool(
            await self.session.scalar(
                select(func.count(Answer.id)).where(
                    Answer.question_id == question_id,
                    Answer.organisation_id == organisation_id,
                    (
                        (Answer.status == AnswerStatus.VERIFIED)
                        | Answer.protected_at.is_not(None)
                    ),
                )
            )
        )

    async def next_version_number(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> int:
        current = await self.session.scalar(
            select(func.max(QuestionVersion.version_number)).where(
                QuestionVersion.question_id == question_id,
                QuestionVersion.organisation_id == organisation_id,
            )
        )
        return int(current or 0) + 1

    async def list_versions(
        self,
        question_id: UUID,
        organisation_id: UUID,
        actor: User,
    ) -> list[tuple[QuestionVersion, User]]:
        rows = await self.session.execute(
            select(QuestionVersion, User)
            .join(User, User.id == QuestionVersion.changed_by)
            .join(Question, Question.id == QuestionVersion.question_id)
            .where(
                QuestionVersion.question_id == question_id,
                QuestionVersion.organisation_id == organisation_id,
                PermissionService.question_visibility_clause(actor),
            )
            .order_by(QuestionVersion.version_number.desc())
        )
        return [(row.QuestionVersion, row.User) for row in rows]

    async def add_change_request(
        self,
        request: QuestionChangeRequest,
    ) -> QuestionChangeRequest:
        self.session.add(request)
        await self.session.flush()
        return request

    async def get_change_request(
        self,
        request_id: UUID,
        organisation_id: UUID,
    ) -> tuple[QuestionChangeRequest, Question] | None:
        row = (
            await self.session.execute(
                select(QuestionChangeRequest, Question)
                .join(Question, Question.id == QuestionChangeRequest.question_id)
                .where(
                    QuestionChangeRequest.id == request_id,
                    QuestionChangeRequest.organisation_id == organisation_id,
                    Question.organisation_id == organisation_id,
                )
            )
        ).one_or_none()
        return (row.QuestionChangeRequest, row.Question) if row else None

    async def list_change_requests(
        self,
        organisation_id: UUID,
        actor: User,
        status: ChangeRequestStatus = ChangeRequestStatus.PENDING,
        limit: int = 50,
    ) -> list[tuple[QuestionChangeRequest, Question, User]]:
        rows = await self.session.execute(
            select(QuestionChangeRequest, Question, User)
            .join(Question, Question.id == QuestionChangeRequest.question_id)
            .join(User, User.id == QuestionChangeRequest.requested_by)
            .where(
                QuestionChangeRequest.organisation_id == organisation_id,
                Question.organisation_id == organisation_id,
                QuestionChangeRequest.status == status,
                PermissionService.question_visibility_clause(actor),
            )
            .order_by(QuestionChangeRequest.created_at.asc())
            .limit(limit)
        )
        return [
            (row.QuestionChangeRequest, row.Question, row.User) for row in rows
        ]