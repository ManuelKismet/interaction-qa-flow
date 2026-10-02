import re
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

    def _candidate_statement(
        self,
        *,
        organisation_id: UUID,
        actor: User,
        include_unanswered: bool = False,
    ):
        canonical_question = aliased(Question)
        candidate_answer = aliased(Answer)
        answer_statuses = [
            AnswerStatus.VERIFIED,
            AnswerStatus.COMMUNITY,
            AnswerStatus.PROPOSED,
        ]
        answer_order = (
            case((candidate_answer.status == AnswerStatus.VERIFIED, 0), else_=1),
            case(
                (candidate_answer.id == canonical_question.accepted_answer_id, 0),
                else_=1,
            ),
            case((candidate_answer.status == AnswerStatus.COMMUNITY, 0), else_=1),
            candidate_answer.created_at.desc(),
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
                open_challenge_count.label("open_challenge_count"),
            )
            .join(
                canonical_question,
                canonical_question.id
                == func.coalesce(Question.canonical_question_id, Question.id),
            )
        )
        answer_join = and_(
            candidate_answer.question_id == canonical_question.id,
            candidate_answer.organisation_id == organisation_id,
            candidate_answer.status.in_(answer_statuses),
            candidate_answer.archived_at.is_(None),
        )
        statement = (
            statement.outerjoin(candidate_answer, answer_join)
            if include_unanswered
            else statement.join(candidate_answer, answer_join)
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
                Question.status.in_(eligible_statuses),
                canonical_question.status.in_(eligible_statuses),
                visibility,
                canonical_visibility,
            )
        )
        return statement, canonical_question, answer_order

    @staticmethod
    def _tokens(query_text: str) -> list[str]:
        return list(
            dict.fromkeys(re.findall(r"[a-zA-Z0-9]+", query_text.lower()))
        )[:40]

    @staticmethod
    def _candidate_rows(result):
        return [
            (
                row[0],
                row[1],
                row[2],
                row[3],
                row[4],
                float(row[6]),
                int(row[5]),
            )
            for row in result
        ]

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
        statement, _, answer_order = self._candidate_statement(
            organisation_id=organisation_id,
            actor=actor,
            include_unanswered=include_unanswered,
        )
        distance = QuestionEmbedding.embedding.cosine_distance(query_embedding)
        statement = (
            statement.join(
                QuestionEmbedding,
                (QuestionEmbedding.question_id == Question.id)
                & (QuestionEmbedding.organisation_id == organisation_id),
            )
            .add_columns((1 - distance).label("similarity"))
            .where(
                QuestionEmbedding.embedding_model == embedding_model,
                or_(
                    distance <= 1 - minimum_similarity,
                    func.lower(func.trim(Question.title))
                    == query_text.strip().lower(),
                ),
            )
            .order_by(distance.asc(), *answer_order)
            .limit(limit)
        )
        result = await self.session.execute(statement)
        return self._candidate_rows(result)

    async def lexical_candidates(
        self,
        *,
        organisation_id: UUID,
        actor: User,
        query_text: str,
        limit: int,
        include_unanswered: bool = False,
    ) -> list[
        tuple[Question, Question, Answer | None, Department | None, Team | None, float, int]
    ]:
        tokens = self._tokens(query_text)
        if not tokens and not query_text.strip():
            return []

        statement, canonical_question, answer_order = self._candidate_statement(
            organisation_id=organisation_id,
            actor=actor,
            include_unanswered=include_unanswered,
        )
        exact_title = func.lower(func.trim(Question.title)) == query_text.strip().lower()
        if self.session.get_bind().dialect.name == "postgresql" and tokens:
            title_vector = func.setweight(
                func.to_tsvector("simple", func.coalesce(Question.title, "")), "A"
            )
            body_vector = func.setweight(
                func.to_tsvector("simple", func.coalesce(Question.body, "")), "B"
            )
            document = title_vector.op("||")(body_vector)
            search_document = func.to_tsvector(
                "simple",
                func.coalesce(Question.title, "")
                + " "
                + func.coalesce(Question.body, ""),
            )
            lexical_query = func.to_tsquery(
                "simple", " | ".join(f"{token}:*" for token in tokens)
            )
            all_terms_query = func.to_tsquery(
                "simple", " & ".join(f"{token}:*" for token in tokens)
            )
            text_match = search_document.op("@@")(lexical_query)
            score = (
                func.ts_rank_cd(document, lexical_query)
                + func.ts_rank_cd(document, all_terms_query)
                + case((exact_title, 10.0), else_=0.0)
            )
            identifier_matches = [
                Question.title.ilike(f"%{token}%", escape="\\")
                | Question.body.ilike(f"%{token}%", escape="\\")
                for token in tokens
            ]
        else:
            title_matches = [
                func.lower(Question.title).contains(token) for token in tokens
            ]
            body_matches = [
                func.lower(func.coalesce(Question.body, "")).contains(token)
                for token in tokens
            ]
            text_match = (
                or_(*title_matches, *body_matches) if tokens else exact_title
            )
            score = case((exact_title, 100.0), else_=0.0)
            score += sum(
                case((match, 10.0), else_=0.0) for match in title_matches
            )
            score += sum(case((match, 1.0), else_=0.0) for match in body_matches)
            all_terms_match = (
                and_(
                    *(
                        or_(title_match, body_match)
                        for title_match, body_match in zip(
                            title_matches, body_matches
                        )
                    )
                )
                if tokens
                else exact_title
            )
            score += case((all_terms_match, 5.0), else_=0.0)
            identifier_matches = []

        statement = (
            statement.add_columns(score.label("similarity"))
            .where(or_(exact_title, text_match, *identifier_matches))
            .order_by(
                score.desc(),
                *answer_order,
                canonical_question.updated_at.desc(),
            )
            .limit(limit)
        )
        result = await self.session.execute(statement)
        return self._candidate_rows(result)