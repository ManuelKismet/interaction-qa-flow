from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.database import get_session
from app.schemas.team import (
    TeamCreate,
    TeamMemberCreate,
    TeamMembershipResponse,
    TeamResponse,
    TeamUpdate,
)
from app.services.team import TeamService

router = APIRouter(prefix="/teams", tags=["teams"])


@router.get("", response_model=list[TeamResponse])
async def list_teams(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[TeamResponse]:
    return await TeamService(session).list(
        identity.organisation_id, identity.user_id
    )


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create_team(
    payload: TeamCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> TeamResponse:
    return await TeamService(session).create(
        identity.organisation_id, identity.user_id, payload
    )


@router.get("/{team_id}", response_model=TeamResponse)
async def get_team(
    team_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> TeamResponse:
    return await TeamService(session).get(
        team_id, identity.organisation_id, identity.user_id
    )


@router.patch("/{team_id}", response_model=TeamResponse)
async def update_team(
    team_id: UUID,
    payload: TeamUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> TeamResponse:
    return await TeamService(session).update(
        team_id, identity.organisation_id, identity.user_id, payload
    )


@router.get("/{team_id}/members", response_model=list[TeamMembershipResponse])
async def list_team_members(
    team_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[TeamMembershipResponse]:
    return await TeamService(session).members(
        team_id, identity.organisation_id, identity.user_id
    )


@router.post(
    "/{team_id}/members",
    response_model=TeamMembershipResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_team_member(
    team_id: UUID,
    payload: TeamMemberCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> TeamMembershipResponse:
    return await TeamService(session).add_member(
        team_id, identity.organisation_id, identity.user_id, payload
    )


@router.delete("/{team_id}/members/{member_user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_team_member(
    team_id: UUID,
    member_user_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await TeamService(session).remove_member(
        team_id,
        member_user_id,
        identity.organisation_id,
        identity.user_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)