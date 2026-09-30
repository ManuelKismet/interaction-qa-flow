from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.organisation import Organisation
from app.repositories.organisation import OrganisationRepository
from app.schemas.organisation import OrganisationCreate


class OrganisationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.organisations = OrganisationRepository(session)

    async def create(self, data: OrganisationCreate) -> Organisation:
        if await self.organisations.get_by_slug(data.slug):
            raise ConflictError("An organisation with this slug already exists")

        organisation = Organisation(**data.model_dump())
        await self.organisations.add(organisation)
        await self.session.commit()
        await self.session.refresh(organisation)
        return organisation