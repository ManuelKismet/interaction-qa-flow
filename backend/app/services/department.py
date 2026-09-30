from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.models.department import Department
from app.repositories.department import DepartmentRepository
from app.repositories.organisation import OrganisationRepository
from app.schemas.department import DepartmentCreate


class DepartmentService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.departments = DepartmentRepository(session)
        self.organisations = OrganisationRepository(session)

    async def create(self, data: DepartmentCreate) -> Department:
        if not await self.organisations.get(data.organisation_id):
            raise NotFoundError("Organisation not found")

        department = Department(**data.model_dump())
        await self.departments.add(department)
        await self.session.commit()
        await self.session.refresh(department)
        return department

    async def list(self, organisation_id: UUID) -> list[Department]:
        if not await self.organisations.get(organisation_id):
            raise NotFoundError("Organisation not found")
        return await self.departments.list_for_organisation(organisation_id)