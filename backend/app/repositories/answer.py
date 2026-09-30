from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.answer import Answer
from app.models.answer_challenge import AnswerChallenge, ChallengeStatus
from app.models.answer_reaction import AnswerReaction, ReactionType
from app.models.user import User


class AnswerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, answer: Answer) -> Answer:
        self.session.add(answer)
        await self.session.flush()
        return answer

    async def get_for_organisation(
        self,
        answer_id: UUID,
        organisation_id: UUID,
    ) -> Answer | None:
        result = await self.session.execute(
            select(Answer).where(
                Answer.id == answer_id,
                Answer.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_details_for_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> list[tuple[Answer, User, User | None, int, int, int]]:
        verifier = aliased(User)
        helpful_count = func.count(
            case((AnswerReaction.reaction == ReactionType.HELPFUL, 1))
        )
        not_helpful_count = func.count(
            case((AnswerReaction.reaction == ReactionType.NOT_HELPFUL, 1))
        )
        challenge_count = (
            select(func.count(AnswerChallenge.id))
            .where(
                AnswerChallenge.answer_id == Answer.id,
                AnswerChallenge.organisation_id == organisation_id,
                AnswerChallenge.status == ChallengeStatus.OPEN,
            )
            .correlate(Answer)
            .scalar_subquery()
        )
        result = await self.session.execute(
            select(
                Answer,
                User,
                verifier,
                helpful_count.label("helpful_count"),
                not_helpful_count.label("not_helpful_count"),
                challenge_count.label("challenge_count"),
            )
            .join(
                User,
                (User.id == Answer.author_id)
                & (User.organisation_id == organisation_id),
            )
            .outerjoin(
                verifier,
                (verifier.id == Answer.verified_by)
                & (verifier.organisation_id == organisation_id),
            )
            .outerjoin(
                AnswerReaction,
                (AnswerReaction.answer_id == Answer.id)
                & (AnswerReaction.organisation_id == organisation_id),
            )
            .where(
                Answer.question_id == question_id,
                Answer.organisation_id == organisation_id,
            )
            .group_by(Answer.id, User.id, verifier.id)
            .order_by(Answer.created_at.asc())
        )
        return [
            (
                row.Answer,
                row.User,
                row[2],
                row.helpful_count,
                row.not_helpful_count,
                row.challenge_count,
            )
            for row in result
        ]

    async def delete(self, answer: Answer) -> None:
        await self.session.delete(answer)


class AnswerReactionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(
        self,
        answer_id: UUID,
        user_id: UUID,
        organisation_id: UUID,
    ) -> AnswerReaction | None:
        result = await self.session.execute(
            select(AnswerReaction).where(
                AnswerReaction.answer_id == answer_id,
                AnswerReaction.user_id == user_id,
                AnswerReaction.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def add(self, reaction: AnswerReaction) -> AnswerReaction:
        self.session.add(reaction)
        await self.session.flush()
        return reaction

    async def counts(self, answer_id: UUID, organisation_id: UUID) -> tuple[int, int]:
        row = (
            await self.session.execute(
                select(
                    func.count(
                        case((AnswerReaction.reaction == ReactionType.HELPFUL, 1))
                    ).label("helpful_count"),
                    func.count(
                        case(
                            (AnswerReaction.reaction == ReactionType.NOT_HELPFUL, 1)
                        )
                    ).label("not_helpful_count"),
                ).where(
                    AnswerReaction.answer_id == answer_id,
                    AnswerReaction.organisation_id == organisation_id,
                )
            )
        ).one()
        return row.helpful_count, row.not_helpful_count