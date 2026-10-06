from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import GuestIdentity, get_guest_identity, require_app_check
from app.core.database import get_session
from app.schemas.personal_workspace import (
    PersonalWorkspaceImport,
    PersonalWorkspaceImportResult,
    PersonalWorkspaceItemResult,
    PersonalWorkspaceItemUpdate,
)
from app.services.personal_workspace import PersonalWorkspaceService


async def reject_identity_overrides(request: Request) -> None:
    if any(
        header in request.headers
        for header in ("x-user-id", "x-organisation-id", "x-user-role")
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Caller-selected identity and organisation headers are not accepted.",
        )


def require_verified_personal_identity(
    identity: GuestIdentity = Depends(get_guest_identity),
) -> None:
    if identity.sign_in_provider == "anonymous":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="A registered account is required to use personal storage.",
        )
    if not identity.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Verify your email address before using personal storage.",
        )


router = APIRouter(
    prefix="/personal",
    tags=["personal workspace"],
    dependencies=[
        Depends(require_app_check),
        Depends(require_verified_personal_identity),
        Depends(reject_identity_overrides),
    ],
)


@router.get("/items", response_model=list[PersonalWorkspaceItemResult])
async def list_items(
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await PersonalWorkspaceService(session).list_items(identity.firebase_uid)


@router.post(
    "/items/import",
    response_model=PersonalWorkspaceImportResult,
    status_code=status.HTTP_201_CREATED,
)
async def import_items(
    payload: PersonalWorkspaceImport,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await PersonalWorkspaceService(session).import_items(
        identity.firebase_uid, payload.items
    )


@router.put("/items/{item_id}", response_model=PersonalWorkspaceItemResult)
async def update_item(
    item_id: UUID,
    payload: PersonalWorkspaceItemUpdate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await PersonalWorkspaceService(session).update_item(
        identity.firebase_uid,
        item_id,
        expected_revision=payload.expected_revision,
        title=payload.title,
        data=payload.data,
    )


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(
    item_id: UUID,
    expected_revision: int = Query(ge=1),
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await PersonalWorkspaceService(session).delete_item(
        identity.firebase_uid,
        item_id,
        expected_revision=expected_revision,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
