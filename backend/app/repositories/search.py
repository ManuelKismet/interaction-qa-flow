import re
from uuid import UUID

from sqlalchemy import and_, case, func, literal, literal_column, or_, select
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

    @staticmethod
    def _weighted_search_document(title, body, answer):
        title_vector = func.setweight(
            func.to_tsvector("simple", func.coalesce(title, "")),
            literal_column("'A'"),
        )
        body_vector = func.setweight(
            func.to_tsvector("simple", func.coalesce(body, "")),
            literal_column("'B'"),
        )
        answer_vector = func.setweight(
            func.to_tsvector("simple", func.coalesce(answer, "")),
            literal_column("'C'"),
        )
        return title_vector.op("||")(body_vector).op("||")(answer_vector)

    def _candidate_statement(
        self,
        *,
        organisation_id: UUID,
        actor: User,
        include_unanswered: bool = False,
    ):
        canonical_question = aliased(Question)
        answer_to_rank = aliased(Answer)
        answer_question = aliased(Question)
        answer_statuses = [
            AnswerStatus.VERIFIED,
            AnswerStatus.COMMUNITY,
            AnswerStatus.PROPOSED,
        ]
        answer_order = (
            case((answer_to_rank.status == AnswerStatus.VERIFIED, 0), else_=1),
            case(
                (answer_to_rank.id == answer_question.accepted_answer_id, 0),
                else_=1,
            ),
            case((answer_to_rank.status == AnswerStatus.COMMUNITY, 0), else_=1),
            answer_to_rank.created_at.desc(),
            answer_to_rank.id.desc(),
        )
        ranked_answers = (
            select(
                answer_to_rank.id.label("answer_id"),
                answer_to_rank.question_id.label("question_id"),
                func.row_number()
                .over(
                    partition_by=answer_to_rank.question_id,
                    order_by=answer_order,
                )
                .label("answer_rank"),
            )
            .join(
                answer_question,
                answer_question.id == answer_to_rank.question_id,
            )
            .where(
                answer_to_rank.organisation_id == organisation_id,
                answer_to_rank.status.in_(answer_statuses),
                answer_to_rank.archived_at.is_(None),
            )
            .subquery()
        )
        candidate_answer = aliased(Answer)
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
            .select_from(Question)
            .join(
                canonical_question,
                canonical_question.id
                == func.coalesce(Question.canonical_question_id, Question.id),
            )
        )
        answer_join = and_(
            ranked_answers.c.question_id == canonical_question.id,
            ranked_answers.c.answer_rank == 1,
        )
        if include_unanswered:
            statement = statement.outerjoin(ranked_answers, answer_join).outerjoin(
                candidate_answer,
                candidate_answer.id == ranked_answers.c.answer_id,
            )
        else:
            statement = statement.join(ranked_answers, answer_join).join(
                candidate_answer,
                candidate_answer.id == ranked_answers.c.answer_id,
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
        return statement, canonical_question, candidate_answer

    @staticmethod
    def _limit_distinct_candidates(
        statement,
        canonical_question,
        *,
        order_by: tuple,
        limit: int,
    ):
        ranked_candidates = (
            statement.with_only_columns(
                Question.id.label("matched_question_id"),
                func.row_number()
                .over(
                    partition_by=canonical_question.id,
                    order_by=(*order_by, Question.id.asc()),
                )
                .label("canonical_rank"),
                maintain_column_froms=True,
            )
            .order_by(None)
            .subquery()
        )
        return (
            statement.where(
                Question.id.in_(
                    select(ranked_candidates.c.matched_question_id).where(
                        ranked_candidates.c.canonical_rank == 1
                    )
                )
            )
            .order_by(*order_by, Question.id.asc())
            .limit(limit)
        )

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
        if embedding_model.startswith("deterministic-fake-"):
            return []
        statement, canonical_question, _ = self._candidate_statement(
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
        )
        statement = self._limit_distinct_candidates(
            statement,
            canonical_question,
            order_by=(distance.asc(),),
            limit=limit,
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

        statement, canonical_question, candidate_answer = self._candidate_statement(
            organisation_id=organisation_id,
            actor=actor,
            include_unanswered=include_unanswered,
        )
        exact_title = func.lower(func.trim(Question.title)) == query_text.strip().lower()
        fuzzy_matches = []
        if self.session.get_bind().dialect.name == "postgresql" and tokens:
            document = self._weighted_search_document(
                Question.title,
                Question.body,
                candidate_answer.body,
            )
            search_document = func.to_tsvector(
                "simple",
                func.coalesce(Question.title, "")
                + " "
                + func.coalesce(Question.body, ""),
            ).op("||")(
                func.to_tsvector("simple", func.coalesce(candidate_answer.body, ""))
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
                | candidate_answer.body.ilike(f"%{token}%", escape="\\")
                for token in tokens
            ]
            fuzzy_matches = [
                or_(
                    literal(token).op("<%")(Question.title),
                    literal(token).op("<%")(Question.body),
                    literal(token).op("<%")(candidate_answer.body),
                )
                for token in tokens
                if len(token) >= 4
            ]
            score += sum(
                case((match, 0.5), else_=0.0) for match in fuzzy_matches
            )
            text_match = or_(text_match, *fuzzy_matches)
        else:
            title_matches = [
                func.lower(Question.title).contains(token) for token in tokens
            ]
            body_matches = [
                func.lower(func.coalesce(Question.body, "")).contains(token)
                for token in tokens
            ]
            answer_matches = [
                func.lower(func.coalesce(candidate_answer.body, "")).contains(token)
                for token in tokens
            ]
            text_match = (
                or_(*title_matches, *body_matches, *answer_matches)
                if tokens
                else exact_title
            )
            score = case((exact_title, 100.0), else_=0.0)
            score += sum(
                case((match, 10.0), else_=0.0) for match in title_matches
            )
            score += sum(case((match, 1.0), else_=0.0) for match in body_matches)
            score += sum(case((match, 1.0), else_=0.0) for match in answer_matches)
            all_terms_match = (
                and_(
                    *(
                        or_(title_match, body_match, answer_match)
                        for title_match, body_match, answer_match in zip(
                            title_matches, body_matches, answer_matches
                        )
                    )
                )
                if tokens
                else exact_title
            )
            score += case((all_terms_match, 5.0), else_=0.0)
            identifier_matches = []

        statement = statement.add_columns(score.label("similarity")).where(
            or_(exact_title, text_match, *identifier_matches, *fuzzy_matches)
        )
        statement = self._limit_distinct_candidates(
            statement,
            canonical_question,
            order_by=(score.desc(), canonical_question.updated_at.desc()),
            limit=limit,
        )
        result = await self.session.execute(statement)
        return self._candidate_rows(result)