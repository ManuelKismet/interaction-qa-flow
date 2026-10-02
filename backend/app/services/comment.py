from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.models.comment import Comment
from app.models.question import Question, QuestionStatus
from app.models.user import User
from app.repositories.answer import AnswerRepository
from app.repositories.comment import CommentRepository
from app.repositories.question import QuestionRepository
from app.repositories.user import UserRepository
from app.schemas.comment import CommentCreate, CommentResponse, CommentUpdate
from app.schemas.user import UserSummary
from app.services.permissions import PermissionService


class CommentService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.answers = AnswerRepository(session)
        self.comments = CommentRepository(session)
        self.questions = QuestionRepository(session)
        self.users = UserRepository(session)
        self.permissions = PermissionService(self.users)

    async def create(self, question_id: UUID, data: CommentCreate) -> CommentResponse:
        question, author = await self._visible_question(
            question_id, data.organisation_id, data.author_id
        )
        if question.status == QuestionStatus.ARCHIVED:
            raise ConflictError("Archived questions cannot receive new comments")
        if data.answer_id:
            answer = await self.answers.get_for_organisation(
                data.answer_id,
                data.organisation_id,
            )
            if not answer or answer.question_id != question_id:
                raise NotFoundError("Answer not found for this question")
        comment = Comment(question_id=question_id, **data.model_dump())
        question.contribution_started_at = (
            question.contribution_started_at or datetime.now(UTC)
        )
        await self.comments.add(comment)
        await self.session.commit()
        await self.session.refresh(comment)
        return self._response(comment, author)

    async def list(
        self, question_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> list[CommentResponse]:
        await self._visible_question(question_id, organisation_id, user_id)
        rows = await self.comments.list_for_question(question_id, organisation_id)
        return [self._response(comment, author) for comment, author in rows]

    async def update(self, comment_id: UUID, data: CommentUpdate) -> CommentResponse:
        comment = await self._owned_comment(comment_id, data.organisation_id, data.user_id)
        author = await self.permissions.actor(data.user_id, data.organisation_id)
        comment.body = data.body
        await self.session.commit()
        await self.session.refresh(comment)
        return self._response(comment, author)

    async def delete(self, comment_id: UUID, organisation_id: UUID, user_id: UUID) -> None:
        comment = await self._owned_comment(comment_id, organisation_id, user_id)
        await self.comments.delete(comment)
        await self.session.commit()

    async def _owned_comment(
        self,
        comment_id: UUID,
        organisation_id: UUID,
        user_id: UUID,
    ) -> Comment:
        comment = await self.comments.get_for_organisation(comment_id, organisation_id)
        if not comment:
            raise NotFoundError("Comment not found")
        _, actor = await self._visible_question(
            comment.question_id, organisation_id, user_id
        )
        self.permissions.require_owner(actor, comment.author_id)
        return comment

    async def _visible_question(
        self, question_id: UUID, organisation_id: UUID, user_id: UUID
    ) -> tuple[Question, User]:
        question = await self.questions.get_for_organisation(
            question_id, organisation_id
        )
        if not question:
            raise NotFoundError("Question not found")
        actor = await self.permissions.actor(user_id, organisation_id)
        self.permissions.require_question_visibility(actor, question)
        return question, actor

    @staticmethod
    def _response(comment: Comment, author: User) -> CommentResponse:
        return CommentResponse.model_validate(
            {
                **comment.__dict__,
                "author": UserSummary.model_validate(author),
            }
        )