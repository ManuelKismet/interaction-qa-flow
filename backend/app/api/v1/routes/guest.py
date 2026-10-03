from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    GuestIdentity,
    get_guest_identity,
    require_app_check,
)
from app.core.database import get_session
from app.schemas.guest import (
    GuestGroupCreate,
    GuestGroupEntryCreate,
    GuestGroupEntryUpdate,
    GuestGroupImport,
    GuestInvitationCreate,
    GuestInvitationToken,
    GuestJoinRequest,
    GuestMemberRoleUpdate,
)
from app.services.guest import GuestService

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
    prefix="/guest",
    tags=["shared guest groups"],
    dependencies=[Depends(require_app_check), Depends(reject_identity_overrides)],
)


def require_anonymous_identity(identity: GuestIdentity) -> None:
    if identity.sign_in_provider != "anonymous":
        raise HTTPException(
            status_code=403,
            detail="A Firebase anonymous identity is required for this action",
        )


@router.get("/groups")
async def list_groups(
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await GuestService(session).list_groups(identity.firebase_uid)


@router.post("/groups", status_code=status.HTTP_201_CREATED)
async def create_group(
    payload: GuestGroupCreate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    require_anonymous_identity(identity)
    return await GuestService(session).create_group(identity.firebase_uid, payload)


@router.get("/groups/{group_id}")
async def get_group(
    group_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).get_group(group_id, identity.firebase_uid)


@router.post("/groups/{group_id}/invitations")
async def create_invitation(
    group_id: UUID,
    payload: GuestInvitationCreate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).create_invitation(
        group_id, identity.firebase_uid, payload
    )


@router.get("/groups/{group_id}/invitations")
async def list_invitations(
    group_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await GuestService(session).list_invitations(
        group_id, identity.firebase_uid
    )


@router.delete(
    "/groups/{group_id}/invitations/{invitation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_invitation(
    group_id: UUID,
    invitation_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GuestService(session).revoke_invitation(
        group_id, invitation_id, identity.firebase_uid
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/invitations/preview")
async def preview_invitation(
    payload: GuestInvitationToken,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict[str, bool]:
    return await GuestService(session).preview_invitation(
        identity.firebase_uid, payload.token
    )


@router.post("/invitations/join")
async def join_invitation(
    payload: GuestJoinRequest,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    require_anonymous_identity(identity)
    return await GuestService(session).join_invitation(
        identity.firebase_uid, payload.token, payload.display_name
    )


@router.post("/groups/{group_id}/members/{member_id}/approve")
async def approve_member(
    group_id: UUID,
    member_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).approve_member(
        group_id, member_id, identity.firebase_uid
    )


@router.patch("/groups/{group_id}/members/{member_id}/role")
async def update_member_role(
    group_id: UUID,
    member_id: UUID,
    payload: GuestMemberRoleUpdate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).update_member_role(
        group_id, member_id, identity.firebase_uid, payload
    )


@router.delete(
    "/groups/{group_id}/members/{member_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_member(
    group_id: UUID,
    member_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GuestService(session).remove_member(
        group_id, member_id, identity.firebase_uid
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/groups/{group_id}/transfer-administration")
async def transfer_administration(
    group_id: UUID,
    member_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).transfer_administration(
        group_id, member_id, identity.firebase_uid
    )


@router.delete("/groups/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_group(
    group_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GuestService(session).revoke_group(group_id, identity.firebase_uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/groups/{group_id}/entries")
async def search_entries(
    group_id: UUID,
    query: str = Query(default="", max_length=200),
    kind: Literal["knowledge", "interact_session"] | None = None,
    limit: int = Query(default=50, ge=1, le=50),
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await GuestService(session).search_entries(
        group_id,
        identity.firebase_uid,
        query,
        kind=kind,
        limit=limit,
    )


@router.post(
    "/groups/{group_id}/entries",
    status_code=status.HTTP_201_CREATED,
)
async def create_entry(
    group_id: UUID,
    payload: GuestGroupEntryCreate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).create_entry(
        group_id, identity.firebase_uid, payload
    )


@router.post("/groups/{group_id}/import")
async def import_entries(
    group_id: UUID,
    payload: GuestGroupImport,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await GuestService(session).import_entries(
        group_id, identity.firebase_uid, payload.entries
    )


@router.get("/groups/{group_id}/entries/{entry_id}")
async def get_entry(
    group_id: UUID,
    entry_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).get_entry(
        group_id, entry_id, identity.firebase_uid
    )


@router.patch("/groups/{group_id}/entries/{entry_id}")
async def update_entry(
    group_id: UUID,
    entry_id: UUID,
    payload: GuestGroupEntryUpdate,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).update_entry(
        group_id, entry_id, identity.firebase_uid, payload
    )


@router.delete(
    "/groups/{group_id}/entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_entry(
    group_id: UUID,
    entry_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GuestService(session).delete_entry(
        group_id, entry_id, identity.firebase_uid
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/groups/{group_id}/entries/{entry_id}/history")
async def entry_history(
    group_id: UUID,
    entry_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await GuestService(session).entry_history(
        group_id, entry_id, identity.firebase_uid
    )


@router.get("/groups/{group_id}/entries/{entry_id}/export")
async def export_entry(
    group_id: UUID,
    entry_id: UUID,
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await GuestService(session).export_entry(
        group_id, entry_id, identity.firebase_uid
    )
