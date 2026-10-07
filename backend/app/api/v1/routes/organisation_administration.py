from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.database import get_session
from app.models.organisation_join_request import OrganisationJoinRequest
from app.models.organisation_permission import OrganisationPermissionGrant
from app.schemas.organisation_administration import (
    OrganisationJoinRequestCreate,
    OrganisationJoinRequestDecision,
    OrganisationJoinRequestResponse,
    OrganisationPermissionCreate,
    OrganisationPermissionResponse,
    OrganisationOwnerSummary,
    OrganisationProfile,
    OwnerAppointment,
)
from app.services.organisation_administration import (
    OrganisationAdministrationService,
)

router = APIRouter(prefix="/organisation", tags=["organisation administration"])


@router.get("/me", response_model=OrganisationProfile)
async def organisation_profile(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await OrganisationAdministrationService(session).profile(
        identity.organisation_id, identity.user_id
    )


@router.get("/permissions", response_model=list[OrganisationPermissionResponse])
async def list_permissions(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[OrganisationPermissionGrant]:
    return await OrganisationAdministrationService(session).list_grants(
        identity.organisation_id, identity.user_id
    )


@router.get("/owners", response_model=list[OrganisationOwnerSummary])
async def list_owners(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[OrganisationOwnerSummary]:
    return await OrganisationAdministrationService(session).list_owners(
        identity.organisation_id, identity.user_id
    )


@router.post(
    "/permissions",
    response_model=OrganisationPermissionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def grant_permission(
    payload: OrganisationPermissionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> OrganisationPermissionGrant:
    return await OrganisationAdministrationService(session).grant(
        identity.organisation_id, identity.user_id, payload
    )


@router.delete("/permissions/{grant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_permission(
    grant_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await OrganisationAdministrationService(session).revoke_grant(
        identity.organisation_id, identity.user_id, grant_id
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/owners", status_code=status.HTTP_201_CREATED)
async def appoint_owner(
    payload: OwnerAppointment,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    owner = await OrganisationAdministrationService(session).appoint_owner(
        identity.organisation_id, identity.user_id, payload.user_id
    )
    return {
        "id": str(owner.id),
        "organisation_id": str(owner.organisation_id),
        "user_id": str(owner.user_id),
    }


@router.delete("/owners/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_owner(
    user_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await OrganisationAdministrationService(session).revoke_owner(
        identity.organisation_id, identity.user_id, user_id
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/admins/{user_id}")
async def appoint_admin(
    user_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    member = await OrganisationAdministrationService(session).appoint_admin(
        identity.organisation_id, identity.user_id, user_id
    )
    return {"id": str(member.id), "role": member.role.value}


@router.post(
    "/join-requests",
    response_model=OrganisationJoinRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def request_membership(
    payload: OrganisationJoinRequestCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> OrganisationJoinRequest:
    return await OrganisationAdministrationService(session).request_membership(
        identity.organisation_id, identity.user_id, payload
    )


@router.get(
    "/join-requests",
    response_model=list[OrganisationJoinRequestResponse],
)
async def list_join_requests(
    mine: bool = False,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[OrganisationJoinRequest]:
    return await OrganisationAdministrationService(session).list_requests(
        identity.organisation_id, identity.user_id, pending=not mine
    )


@router.post(
    "/join-requests/{request_id}/decision",
    response_model=OrganisationJoinRequestResponse,
)
async def decide_join_request(
    request_id: UUID,
    payload: OrganisationJoinRequestDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> OrganisationJoinRequest:
    return await OrganisationAdministrationService(session).decide_request(
        identity.organisation_id, identity.user_id, request_id, payload
    )
