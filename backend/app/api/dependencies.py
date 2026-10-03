import logging
from dataclasses import dataclass
from uuid import UUID

from fastapi import Depends, Header, HTTPException, Request, status
from firebase_admin import App, app_check, auth, get_app, initialize_app
from firebase_admin.exceptions import FirebaseError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.models import FirebaseUidMapping, User

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class AuthenticatedIdentity:
    organisation_id: UUID
    user_id: UUID
    firebase_uid: str
    email: str
    display_name: str
    role: str


@dataclass(frozen=True)
class GuestIdentity:
    firebase_uid: str
    sign_in_provider: str


DevelopmentIdentity = AuthenticatedIdentity


def firebase_app(settings: Settings) -> App:
    try:
        app = get_app()
    except ValueError:
        app = initialize_app(options={"projectId": settings.firebase_project_id})
    if app.project_id != settings.firebase_project_id:
        raise ValueError("Firebase Admin is initialized for an unexpected project")
    return app


def verify_id_token(token: str, settings: Settings) -> dict:
    return auth.verify_id_token(token, app=firebase_app(settings), check_revoked=True)


def verify_app_check_token(token: str, settings: Settings) -> dict:
    return app_check.verify_token(token, app=firebase_app(settings))


def unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_development_identity(
    authorization: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedIdentity:
    parts = authorization.split(None, 1) if authorization else []
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise unauthorized()
    token = parts[1].strip()
    if not token:
        raise unauthorized()

    try:
        claims = verify_id_token(token, settings)
    except (FirebaseError, ValueError, TypeError):
        raise unauthorized() from None

    if (
        claims.get("aud") != settings.firebase_project_id
        or claims.get("iss")
        != f"https://securetoken.google.com/{settings.firebase_project_id}"
        or not isinstance(claims.get("sub"), str)
        or not claims["sub"]
    ):
        raise unauthorized()

    result = await session.execute(
        select(User)
        .join(FirebaseUidMapping, FirebaseUidMapping.user_id == User.id)
        .where(FirebaseUidMapping.firebase_uid == claims["sub"])
    )
    user = result.scalar_one_or_none()
    if user is None or user.status != "active":
        raise unauthorized()

    return AuthenticatedIdentity(
        organisation_id=user.organisation_id,
        user_id=user.id,
        firebase_uid=claims["sub"],
        email=user.email,
        display_name=user.display_name,
        role=user.role.value,
    )


async def get_guest_identity(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> GuestIdentity:
    parts = authorization.split(None, 1) if authorization else []
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise unauthorized()
    token = parts[1].strip()
    if not token:
        raise unauthorized()

    try:
        claims = verify_id_token(token, settings)
    except (FirebaseError, ValueError, TypeError):
        raise unauthorized() from None

    firebase_claims = claims.get("firebase")
    sign_in_provider = (
        firebase_claims.get("sign_in_provider")
        if isinstance(firebase_claims, dict)
        else None
    )
    if (
        claims.get("aud") != settings.firebase_project_id
        or claims.get("iss")
        != f"https://securetoken.google.com/{settings.firebase_project_id}"
        or not isinstance(claims.get("sub"), str)
        or not claims["sub"]
        or not isinstance(sign_in_provider, str)
    ):
        raise unauthorized()
    return GuestIdentity(
        firebase_uid=claims["sub"],
        sign_in_provider=sign_in_provider,
    )


async def require_app_check(
    app_check_token: str | None = Header(default=None, alias="X-Firebase-AppCheck"),
    settings: Settings = Depends(get_settings),
) -> None:
    if settings.app_env == "development":
        logger.setLevel(logging.INFO)
        if not logger.handlers:
            logger.addHandler(logging.StreamHandler())
    if not app_check_token:
        if settings.app_check_mode == "enforce":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="App Check token required",
            )
        logger.info("App Check token missing in observation mode")
        return

    try:
        claims = verify_app_check_token(app_check_token, settings)
    except (FirebaseError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid App Check token",
        ) from None

    if claims.get("app_id") != settings.firebase_web_app_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid App Check application",
        )

    if settings.app_env == "development":
        logger.info("Development App Check verified for configured web app")


_ACTOR_FIELDS = {
    "author_id",
    "created_by",
    "answered_by_user_id",
    "proposed_by",
    "reviewed_by",
    "saved_by",
}


def _check_request_data(
    value: object,
    identity: AuthenticatedIdentity,
    *,
    allow_target_user_id: bool,
    top_level: bool = True,
) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "organisation_id" and str(item) != str(identity.organisation_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Cross-organisation request denied",
                )
            caller_user_id = key == "user_id" and not allow_target_user_id
            if (
                ((top_level and key in _ACTOR_FIELDS) or caller_user_id)
                and item is not None
                and str(item) != str(identity.user_id)
            ):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Caller identity cannot be overridden",
                )
            _check_request_data(
                item,
                identity,
                allow_target_user_id=allow_target_user_id,
                top_level=False,
            )
    elif isinstance(value, list):
        for item in value:
            _check_request_data(
                item,
                identity,
                allow_target_user_id=allow_target_user_id,
                top_level=False,
            )


async def enforce_tenant_scope(
    request: Request,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
) -> None:
    if any(
        header in request.headers
        for header in ("x-user-id", "x-organisation-id", "x-user-role")
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Legacy development identity headers are not accepted",
        )

    for value in request.query_params.getlist("organisation_id"):
        if value != str(identity.organisation_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cross-organisation request denied",
            )

    if (
        request.headers.get("content-type", "").startswith("application/json")
        and await request.body()
    ):
        try:
            allow_target_user_id = (
                "/members" in request.url.path
                or "/answer-owners" in request.url.path
            )
            _check_request_data(
                await request.json(),
                identity,
                allow_target_user_id=allow_target_user_id,
            )
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Malformed request body",
            ) from None
