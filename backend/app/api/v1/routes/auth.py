from fastapi import APIRouter, Depends

from app.api.dependencies import AuthenticatedIdentity, get_development_identity

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
