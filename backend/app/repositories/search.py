from uuid import UUID

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.answer import Answer, AnswerStatus
from app.models.answer_challenge import AnswerChallenge, ChallengeStatus
from app.models.department import Department
from app.models.question import Question, QuestionStatus, QuestionVisibility
from app.models.question_embedding import QuestionEmbedding
from app.models.team import Team
from app.models.user import User


class SearchRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def semantic_candidates(
        self,
        *,
        organisation_id: UUID,
        actor: User,
        query_text: str,
        query_embedding: list[float],
        embedding_model: str,
        minimum_similarity: float,
        limit: int,
        include_unanswered: bool = False,
    ) -> list[
        tuple[Question, Question, Answer | None, Department | None, Team | None, float, int]
    ]:
        canonical_question = aliased(Question)
        candidate_answer = aliased(Answer)
        selected_answer_id = (
            select(Answer.id)
            .where(
                Answer.question_id == canonical_question.id,
                Answer.organisation_id == organisation_id,
                Answer.status.in_(
                    [
                        AnswerStatus.VERIFIED,
                        AnswerStatus.COMMUNITY,
                        AnswerStatus.PROPOSED,
                    ]
                ),
            )
            .order_by(
                case(
                    (Answer.status == AnswerStatus.VERIFIED, 0),
                    (Answer.id == canonical_question.accepted_answer_id, 1),
                    (Answer.status == AnswerStatus.COMMUNITY, 2),
                    else_=3,
                ),
                Answer.created_at.desc(),
            )
            .correlate(canonical_question)
            .limit(1)
            .scalar_subquery()
        )
        open_challenge_count = (
            select(func.count(AnswerChallenge.id))
            .where(
                AnswerChallenge.answer_id == candidate_answer.id,
                AnswerChallenge.organisation_id == organisation_id,
                AnswerChallenge.status == ChallengeStatus.OPEN,
            )
            .correlate(candidate_answer)
            .scalar_subquery()
        )
        distance = QuestionEmbedding.embedding.cosine_distance(query_embedding)
        visibility = or_(
            Question.visibility == QuestionVisibility.ORGANISATION,
            and_(
                Question.visibility == QuestionVisibility.PRIVATE,
                Question.author_id == actor.id,
            ),
        )
        if actor.department_id is not None:
            visibility = or_(
                visibility,
                and_(
                    Question.visibility == QuestionVisibility.DEPARTMENT,
                    Question.department_id == actor.department_id,
                ),
            )
        canonical_visibility = or_(
            canonical_question.visibility == QuestionVisibility.ORGANISATION,
            and_(
                canonical_question.visibility == QuestionVisibility.PRIVATE,
                canonical_question.author_id == actor.id,
            ),
        )
        if actor.department_id is not None:
            canonical_visibility = or_(
                canonical_visibility,
                and_(
                    canonical_question.visibility == QuestionVisibility.DEPARTMENT,
                    canonical_question.department_id == actor.department_id,
                ),
            )

        statement = (
            select(
                Question,
                canonical_question,
                candidate_answer,
                Department,
                Team,
                (1 - distance).label("similarity"),
                open_challenge_count.label("open_challenge_count"),
            )
            .join(
                QuestionEmbedding,
                (QuestionEmbedding.question_id == Question.id)
                & (QuestionEmbedding.organisation_id == organisation_id),
            )
            .join(
                canonical_question,
                canonical_question.id
                == func.coalesce(Question.canonical_question_id, Question.id),
            )
        )
        statement = (
            statement.outerjoin(candidate_answer, candidate_answer.id == selected_answer_id)
            if include_unanswered
            else statement.join(candidate_answer, candidate_answer.id == selected_answer_id)
        )
        eligible_statuses = [QuestionStatus.ANSWERED, QuestionStatus.RESOLVED]
        if include_unanswered:
            eligible_statuses.append(QuestionStatus.OPEN)
        statement = (
            statement
            .outerjoin(
                Department,
                (Department.id == canonical_question.department_id)
                & (Department.organisation_id == organisation_id),
            )
            .outerjoin(
                Team,
                (Team.id == canonical_question.team_id)
                & (Team.organisation_id == organisation_id),
            )
            .where(
                Question.organisation_id == organisation_id,
                canonical_question.organisation_id == organisation_id,
                canonical_question.canonical_question_id.is_(None),
                QuestionEmbedding.embedding_model == embedding_model,
                canonical_question.status.in_(eligible_statuses),
                or_(
                    distance <= 1 - minimum_similarity,
                    func.lower(func.trim(Question.title))
                    == query_text.strip().lower(),
                ),
                visibility,
                canonical_visibility,
            )
            .order_by(distance.asc())
            .limit(limit)
        )
        result = await self.session.execute(statement)
        return [
            (
                row.Question,
                row[1],
                row[2],
                row.Department,
                row.Team,
                float(row.similarity),
                int(row.open_challenge_count),
            )
            for row in result
        ]