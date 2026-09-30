from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_for_organisation(
        self,
        user_id: UUID,
        organisation_id: UUID,
    ) -> User | None:
        result = await self.session.execute(
            select(User).where(
                User.id == user_id,
                User.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()