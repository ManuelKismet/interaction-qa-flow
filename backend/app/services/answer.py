from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import ConflictError, NotFoundError
from app.models.answer import Answer, AnswerStatus
from app.models.answer_reaction import AnswerReaction
from app.models.question import QuestionStatus
from app.repositories.answer import AnswerReactionRepository, AnswerRepository
from app.repositories.question import QuestionRepository
from app.repositories.user import UserRepository
from app.schemas.answer import (
    AnswerCreate,
    AnswerDetailResponse,
    AnswerUpdate,
    ReactionCreate,
    ReactionResponse,
)
from app.schemas.user import UserSummary
from app.services.freshness import answer_freshness
from app.services.permissions import PermissionService


class AnswerService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.answers = AnswerRepository(session)
        self.reactions = AnswerReactionRepository(session)
        self.questions = QuestionRepository(session)
        self.users = UserRepository(session)
        self.permissions = PermissionService(self.users)
        self.settings = get_settings()

    async def create(
        self,
        question_id: UUID,
        data: AnswerCreate,
    ) -> AnswerDetailResponse:
        question = await self.questions.get_for_organisation(
            question_id,
            data.organisation_id,
        )
        if not question:
            raise NotFoundError("Question not found")

        if not await self.users.get_for_organisation(
            data.author_id,
            data.organisation_id,
        ):
            raise NotFoundError("Author not found in this organisation")

        answer = Answer(
            question_id=question_id,
            status=AnswerStatus.COMMUNITY,
            **data.model_dump(),
        )
        await self.answers.add(answer)
        if question.status == QuestionStatus.OPEN:
            question.status = QuestionStatus.ANSWERED
        await self.session.commit()
        await self.session.refresh(answer)
        return await self._detail(answer)

    async def list(self, question_id: UUID, organisation_id: UUID) -> list[AnswerDetailResponse]:
        if not await self.questions.get_for_organisation(question_id, organisation_id):
            raise NotFoundError("Question not found")
        rows = await self.answers.list_details_for_question(question_id, organisation_id)
        question = await self.questions.get_for_organisation(question_id, organisation_id)
        return [
            AnswerDetailResponse.model_validate(
                {
                    **answer.__dict__,
                    "author": UserSummary.model_validate(author),
                    "verified_by_user": UserSummary.model_validate(verifier)
                    if verifier
                    else None,
                    "helpful_count": helpful,
                    "not_helpful_count": not_helpful,
                    "is_accepted": answer.id == question.accepted_answer_id,
                    "freshness_status": answer_freshness(
                        answer,
                        has_open_challenge=challenge_count > 0,
                        due_soon_days=self.settings.review_due_soon_days,
                    ),
                    "challenge_count": challenge_count,
                    "has_open_challenge": challenge_count > 0,
                }
            )
            for answer, author, verifier, helpful, not_helpful, challenge_count in rows
        ]

    async def update(self, answer_id: UUID, data: AnswerUpdate) -> AnswerDetailResponse:
        answer = await self._owned_answer(answer_id, data.organisation_id, data.user_id)
        if answer.status == AnswerStatus.VERIFIED:
            raise ConflictError("Verified answers cannot be edited")
        question = await self.questions.get_for_organisation(
            answer.question_id,
            data.organisation_id,
        )
        if question and question.accepted_answer_id == answer.id:
            raise ConflictError("Accepted answers cannot be edited")
        answer.body = data.body
        await self.session.commit()
        await self.session.refresh(answer)
        return await self._detail(answer)

    async def delete(self, answer_id: UUID, organisation_id: UUID, user_id: UUID) -> None:
        answer = await self._owned_answer(answer_id, organisation_id, user_id)
        question = await self.questions.get_for_organisation(answer.question_id, organisation_id)
        if answer.status == AnswerStatus.VERIFIED or (
            question and question.accepted_answer_id == answer.id
        ):
            raise ConflictError("Verified or accepted answers cannot be deleted")
        await self.answers.delete(answer)
        await self.session.commit()

    async def react(self, answer_id: UUID, data: ReactionCreate) -> ReactionResponse:
        answer = await self.answers.get_for_organisation(answer_id, data.organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        await self.permissions.actor(data.user_id, data.organisation_id)
        reaction = await self.reactions.get(answer_id, data.user_id, data.organisation_id)
        if reaction:
            reaction.reaction = data.reaction
        else:
            reaction = AnswerReaction(
                organisation_id=data.organisation_id,
                answer_id=answer_id,
                user_id=data.user_id,
                reaction=data.reaction,
            )
            await self.reactions.add(reaction)
        await self.session.commit()
        helpful, not_helpful = await self.reactions.counts(answer_id, data.organisation_id)
        return ReactionResponse(
            answer_id=answer_id,
            reaction=reaction.reaction,
            helpful_count=helpful,
            not_helpful_count=not_helpful,
        )

    async def _owned_answer(
        self,
        answer_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> Answer:
        answer = await self.answers.get_for_organisation(answer_id, organisation_id)
        if not answer:
            raise NotFoundError("Answer not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_owner(actor, answer.author_id)
        return answer

    async def _detail(self, answer: Answer) -> AnswerDetailResponse:
        question = await self.questions.get_for_organisation(
            answer.question_id,
            answer.organisation_id,
        )
        rows = await self.answers.list_details_for_question(
            answer.question_id,
            answer.organisation_id,
        )
        for row_answer, author, verifier, helpful, not_helpful, challenge_count in rows:
            if row_answer.id == answer.id:
                return AnswerDetailResponse.model_validate(
                    {
                        **row_answer.__dict__,
                        "author": UserSummary.model_validate(author),
                        "verified_by_user": UserSummary.model_validate(verifier)
                        if verifier
                        else None,
                        "helpful_count": helpful,
                        "not_helpful_count": not_helpful,
                        "is_accepted": bool(
                            question and question.accepted_answer_id == answer.id
                        ),
                        "freshness_status": answer_freshness(
                            row_answer,
                            has_open_challenge=challenge_count > 0,
                            due_soon_days=self.settings.review_due_soon_days,
                        ),
                        "challenge_count": challenge_count,
                        "has_open_challenge": challenge_count > 0,
                    }
                )
        raise NotFoundError("Answer not found")