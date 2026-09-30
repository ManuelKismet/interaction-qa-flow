from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.answer import Answer, AnswerStatus
from app.models.answer_challenge import AnswerChallenge, ChallengeStatus
from app.models.answer_version import AnswerVersion
from app.models.audit_event import AuditEvent
from app.models.department import Department
from app.models.department_answer_owner import DepartmentAnswerOwner
from app.models.question import Question, QuestionStatus
from app.models.team import Team
from app.models.user import User


class GovernanceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def is_department_owner(
        self,
        organisation_id: UUID,
        department_id: UUID,
        user_id: UUID,
    ) -> bool:
        return bool(
            await self.session.scalar(
                select(func.count(DepartmentAnswerOwner.id)).where(
                    DepartmentAnswerOwner.organisation_id == organisation_id,
                    DepartmentAnswerOwner.department_id == department_id,
                    DepartmentAnswerOwner.user_id == user_id,
                )
            )
        )

    async def team_department_id(
        self,
        team_id: UUID,
        organisation_id: UUID,
    ) -> UUID | None:
        return await self.session.scalar(
            select(Team.department_id).where(
                Team.id == team_id,
                Team.organisation_id == organisation_id,
            )
        )

    async def get_question_for_update(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> Question | None:
        return (
            await self.session.execute(
                select(Question)
                .where(
                    Question.id == question_id,
                    Question.organisation_id == organisation_id,
                )
                .with_for_update()
            )
        ).scalar_one_or_none()

    async def verified_answer(
        self,
        question_id: UUID,
        organisation_id: UUID,
        *,
        exclude_answer_id: UUID | None = None,
    ) -> Answer | None:
        statement = select(Answer).where(
            Answer.question_id == question_id,
            Answer.organisation_id == organisation_id,
            Answer.status == AnswerStatus.VERIFIED,
        )
        if exclude_answer_id:
            statement = statement.where(Answer.id != exclude_answer_id)
        return (await self.session.execute(statement)).scalar_one_or_none()

    async def get_challenge(
        self,
        challenge_id: UUID,
        organisation_id: UUID,
        *,
        for_update: bool = False,
    ) -> AnswerChallenge | None:
        statement = select(AnswerChallenge).where(
            AnswerChallenge.id == challenge_id,
            AnswerChallenge.organisation_id == organisation_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self.session.execute(statement)).scalar_one_or_none()

    async def list_challenges(
        self,
        answer_id: UUID,
        organisation_id: UUID,
    ) -> list[AnswerChallenge]:
        return list(
            await self.session.scalars(
                select(AnswerChallenge)
                .where(
                    AnswerChallenge.answer_id == answer_id,
                    AnswerChallenge.organisation_id == organisation_id,
                )
                .order_by(AnswerChallenge.created_at.desc())
            )
        )

    async def open_challenge_count(
        self,
        answer_id: UUID,
        organisation_id: UUID,
    ) -> int:
        return int(
            await self.session.scalar(
                select(func.count(AnswerChallenge.id)).where(
                    AnswerChallenge.answer_id == answer_id,
                    AnswerChallenge.organisation_id == organisation_id,
                    AnswerChallenge.status == ChallengeStatus.OPEN,
                )
            )
            or 0
        )

    async def next_version_number(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> int:
        current = await self.session.scalar(
            select(func.max(AnswerVersion.version_number)).where(
                AnswerVersion.question_id == question_id,
                AnswerVersion.organisation_id == organisation_id,
            )
        )
        return int(current or 0) + 1

    async def list_versions(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> list[tuple[AnswerVersion, User]]:
        rows = await self.session.execute(
            select(AnswerVersion, User)
            .join(User, User.id == AnswerVersion.changed_by)
            .where(
                AnswerVersion.question_id == question_id,
                AnswerVersion.organisation_id == organisation_id,
                User.organisation_id == organisation_id,
            )
            .order_by(AnswerVersion.version_number.desc())
        )
        return [(row.AnswerVersion, row.User) for row in rows]

    async def add(self, entity) -> None:
        self.session.add(entity)
        await self.session.flush()

    async def list_department_owners(
        self,
        organisation_id: UUID,
    ) -> list[tuple[DepartmentAnswerOwner, Department, User]]:
        rows = await self.session.execute(
            select(DepartmentAnswerOwner, Department, User)
            .join(Department, Department.id == DepartmentAnswerOwner.department_id)
            .join(User, User.id == DepartmentAnswerOwner.user_id)
            .where(DepartmentAnswerOwner.organisation_id == organisation_id)
            .order_by(Department.name, User.display_name)
        )
        return [(row.DepartmentAnswerOwner, row.Department, row.User) for row in rows]

    async def get_department_owner(
        self,
        organisation_id: UUID,
        department_id: UUID,
        user_id: UUID,
    ) -> DepartmentAnswerOwner | None:
        return (
            await self.session.execute(
                select(DepartmentAnswerOwner).where(
                    DepartmentAnswerOwner.organisation_id == organisation_id,
                    DepartmentAnswerOwner.department_id == department_id,
                    DepartmentAnswerOwner.user_id == user_id,
                )
            )
        ).scalar_one_or_none()

    async def owned_department_ids(
        self,
        organisation_id: UUID,
        user_id: UUID,
    ) -> list[UUID]:
        return list(
            await self.session.scalars(
                select(DepartmentAnswerOwner.department_id).where(
                    DepartmentAnswerOwner.organisation_id == organisation_id,
                    DepartmentAnswerOwner.user_id == user_id,
                )
            )
        )

    async def review_queue_rows(
        self,
        organisation_id: UUID,
        department_ids: list[UUID] | None,
        due_soon_at: datetime,
        challenge_status: ChallengeStatus = ChallengeStatus.OPEN,
    ) -> tuple[
        list[tuple[AnswerChallenge, Answer, Question, Department | None]],
        list[tuple[Answer, Question, Department | None]],
        list[tuple[Answer, Question, Department | None]],
    ]:
        effective_department_id = func.coalesce(
            Question.department_id, Team.department_id
        )
        department_filter = True
        if department_ids is not None:
            department_filter = effective_department_id.in_(department_ids)

        challenges = list(
            (
                await self.session.execute(
                    select(AnswerChallenge, Answer, Question, Department)
                    .join(Answer, Answer.id == AnswerChallenge.answer_id)
                    .join(Question, Question.id == Answer.question_id)
                    .outerjoin(Team, Team.id == Question.team_id)
                    .outerjoin(Department, Department.id == effective_department_id)
                    .where(
                        AnswerChallenge.organisation_id == organisation_id,
                        AnswerChallenge.status == challenge_status,
                        Question.organisation_id == organisation_id,
                        department_filter,
                    )
                )
            )
        )
        due = list(
            (
                await self.session.execute(
                    select(Answer, Question, Department)
                    .join(Question, Question.id == Answer.question_id)
                    .outerjoin(Team, Team.id == Question.team_id)
                    .outerjoin(Department, Department.id == effective_department_id)
                    .where(
                        Answer.organisation_id == organisation_id,
                        Answer.status == AnswerStatus.VERIFIED,
                        Answer.review_due_at.is_not(None),
                        Answer.review_due_at <= due_soon_at,
                        department_filter,
                    )
                )
            )
        )
        verified_answer = aliased(Answer)
        needs_verification = list(
            (
                await self.session.execute(
                    select(Answer, Question, Department)
                    .join(Question, Question.id == Answer.question_id)
                    .outerjoin(Team, Team.id == Question.team_id)
                    .outerjoin(Department, Department.id == effective_department_id)
                    .where(
                        Answer.organisation_id == organisation_id,
                        Answer.status == AnswerStatus.COMMUNITY,
                        Question.status.in_([QuestionStatus.ANSWERED, QuestionStatus.RESOLVED]),
                        ~select(verified_answer.id)
                        .where(
                            verified_answer.question_id == Question.id,
                            verified_answer.status == AnswerStatus.VERIFIED,
                        )
                        .correlate(Question)
                        .exists(),
                        department_filter,
                    )
                )
            )
        )
        return challenges, due, needs_verification

    async def list_audit_events(
        self,
        organisation_id: UUID,
        limit: int,
    ) -> list[AuditEvent]:
        return list(
            await self.session.scalars(
                select(AuditEvent)
                .where(AuditEvent.organisation_id == organisation_id)
                .order_by(AuditEvent.created_at.desc())
                .limit(limit)
            )
        )