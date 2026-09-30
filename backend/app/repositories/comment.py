from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.comment import Comment
from app.models.user import User


class CommentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def add(self, comment: Comment) -> Comment:
        self.session.add(comment)
        await self.session.flush()
        return comment

    async def get_for_organisation(
        self,
        comment_id: UUID,
        organisation_id: UUID,
    ) -> Comment | None:
        result = await self.session.execute(
            select(Comment).where(
                Comment.id == comment_id,
                Comment.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_for_question(
        self,
        question_id: UUID,
        organisation_id: UUID,
    ) -> list[tuple[Comment, User]]:
        result = await self.session.execute(
            select(Comment, User)
            .join(
                User,
                (User.id == Comment.author_id)
                & (User.organisation_id == organisation_id),
            )
            .where(
                Comment.question_id == question_id,
                Comment.organisation_id == organisation_id,
            )
            .order_by(Comment.created_at.asc())
        )
        return [(row.Comment, row.User) for row in result]

    async def delete(self, comment: Comment) -> None:
        await self.session.delete(comment)