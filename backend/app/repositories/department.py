from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.department import Department


class DepartmentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_for_organisation(
        self,
        department_id: UUID,
        organisation_id: UUID,
    ) -> Department | None:
        result = await self.session.execute(
            select(Department).where(
                Department.id == department_id,
                Department.organisation_id == organisation_id,
            )
        )
        return result.scalar_one_or_none()

    async def add(self, department: Department) -> Department:
        self.session.add(department)
        await self.session.flush()
        return department

    async def list_for_organisation(self, organisation_id: UUID) -> list[Department]:
        result = await self.session.execute(
            select(Department)
            .where(Department.organisation_id == organisation_id)
            .order_by(Department.name.asc())
        )
        return list(result.scalars().all())