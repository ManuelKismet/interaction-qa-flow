from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.schemas.department import DepartmentCreate, DepartmentResponse
from app.services.department import DepartmentService

router = APIRouter(prefix="/departments", tags=["departments"])


@router.get("", response_model=list[DepartmentResponse])
async def list_departments(
    # TODO(auth): derive organisation_id from the authenticated identity.
    organisation_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> list[DepartmentResponse]:
    return await DepartmentService(session).list(organisation_id)


@router.post(
    "",
    response_model=DepartmentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_department(
    payload: DepartmentCreate,
    session: AsyncSession = Depends(get_session),
) -> DepartmentResponse:
    return await DepartmentService(session).create(payload)