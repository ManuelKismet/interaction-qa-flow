from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import GuestIdentity, get_guest_identity, require_app_check
from app.core.database import get_session
from app.models import FirebaseUidMapping, User


async def reject_identity_overrides(request: Request) -> None:
    if any(
        header in request.headers
        for header in ("x-user-id", "x-organisation-id", "x-user-role")
    ):
        raise HTTPException(
            status_code=400,
            detail="Caller-selected identity and organisation headers are not accepted",
        )


router = APIRouter(
    prefix="/account",
    tags=["account"],
    dependencies=[Depends(require_app_check), Depends(reject_identity_overrides)],
)


@router.get("/state")
async def account_state(
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    if identity.sign_in_provider == "anonymous":
        return {"status": "shared_guest"}

    status = await session.scalar(
        select(User.status)
        .join(FirebaseUidMapping, FirebaseUidMapping.user_id == User.id)
        .where(FirebaseUidMapping.firebase_uid == identity.firebase_uid)
    )
    if status is None:
        return {"status": "no_membership"}
    if status != "active":
        return {"status": "inactive"}
    return {"status": "active"}
