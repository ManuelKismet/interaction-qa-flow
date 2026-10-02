from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import AuthenticatedIdentity, get_development_identity
from app.core.database import get_session
from app.repositories.user import UserRepository
from app.schemas.department import DepartmentCreate, DepartmentResponse
from app.services.department import DepartmentService
from app.services.permissions import PermissionService

router = APIRouter(prefix="/departments", tags=["departments"])


@router.get("", response_model=list[DepartmentResponse])
async def list_departments(
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[DepartmentResponse]:
    return await DepartmentService(session).list(identity.organisation_id)


@router.post(
    "",
    response_model=DepartmentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_department(
    payload: DepartmentCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> DepartmentResponse:
    actor = await PermissionService(UserRepository(session)).actor(
        identity.user_id,
        identity.organisation_id,
    )
    PermissionService.require_admin(actor)
    return await DepartmentService(session).create(
        payload.model_copy(update={"organisation_id": identity.organisation_id})
    )