from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.schemas.organisation import OrganisationCreate, OrganisationResponse
from app.services.organisation import OrganisationService

router = APIRouter(prefix="/organisations", tags=["organisations"])


@router.post(
    "",
    response_model=OrganisationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_organisation(
    payload: OrganisationCreate,
    session: AsyncSession = Depends(get_session),
) -> OrganisationResponse:
    return await OrganisationService(session).create(payload)