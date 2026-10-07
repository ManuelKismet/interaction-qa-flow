from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import auth
from firebase_admin.exceptions import FirebaseError
from google.auth.exceptions import GoogleAuthError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.api.dependencies import (
    AuthenticatedIdentity,
    firebase_app,
    get_development_identity,
)
from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.repositories.user import UserRepository
from app.schemas.organisation_member import (
    OrganisationMemberCreate,
    OrganisationMemberResponse,
    OrganisationMemberUpdate,
)
from app.services.organisation_member import OrganisationMemberService
from app.services.permissions import PermissionService

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.get("/me")
async def current_user(
    identity: AuthenticatedIdentity = Depends(get_development_identity),
) -> dict[str, str]:
    return {
        "user_id": str(identity.user_id),
        "organisation_id": str(identity.organisation_id),
        "email": identity.email,
        "display_name": identity.display_name,
        "role": identity.role,
    }


@router.get("/members", response_model=list[OrganisationMemberResponse])
async def list_organisation_members(
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, object]]:
    actor = await PermissionService(UserRepository(session)).actor(
        identity.user_id,
        identity.organisation_id,
    )
    permissions = PermissionService(UserRepository(session))
    if not await permissions.is_organisation_admin(
        actor
    ) and not await permissions.has_any_permission(actor, "team_membership"):
        await permissions.require_admin(actor)
    return await OrganisationMemberService(session).list_members(
        identity.organisation_id
    )


@router.patch(
    "/members/{member_id}",
    response_model=OrganisationMemberResponse,
)
async def update_organisation_member(
    member_id: UUID,
    payload: OrganisationMemberUpdate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> dict[str, object]:
    actor = await PermissionService(UserRepository(session)).actor(
        identity.user_id,
        identity.organisation_id,
    )
    await PermissionService(UserRepository(session)).require_admin(actor)
    return await OrganisationMemberService(session).update_member(
        organisation_id=identity.organisation_id,
        actor_id=actor.id,
        member_id=member_id,
        update=payload,
    )


@router.post(
    "/members",
    response_model=OrganisationMemberResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_organisation_member(
    payload: OrganisationMemberCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> dict[str, object]:
    actor = await PermissionService(UserRepository(session)).actor(
        identity.user_id,
        identity.organisation_id,
    )
    await PermissionService(UserRepository(session)).require_admin(actor)
    try:
        app = firebase_app(settings)
        firebase_user = await run_in_threadpool(
            auth.get_user_by_email,
            payload.email,
            app=app,
        )
    except auth.UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No registered account was found for this email",
        ) from None
    except (FirebaseError, GoogleAuthError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Registered account lookup is temporarily unavailable",
        ) from None
    if not firebase_user.email_verified or not firebase_user.email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Organisation membership requires a verified email account",
        )
    return await OrganisationMemberService(session).add_member(
        organisation_id=identity.organisation_id,
        actor_id=actor.id,
        firebase_uid=firebase_user.uid,
        email=firebase_user.email,
        display_name=firebase_user.display_name,
        update=payload,
    )
