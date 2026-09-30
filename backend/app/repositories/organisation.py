from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.organisation import Organisation


class OrganisationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, organisation_id: UUID) -> Organisation | None:
        return await self.session.get(Organisation, organisation_id)

    async def get_by_slug(self, slug: str) -> Organisation | None:
        result = await self.session.execute(
            select(Organisation).where(Organisation.slug == slug)
        )
        return result.scalar_one_or_none()

    async def add(self, organisation: Organisation) -> Organisation:
        self.session.add(organisation)
        await self.session.flush()
        return organisation