import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.guest import (
    GuestGroup,
    GuestGroupEntry,
    GuestGroupEntryRevision,
    GuestGroupInvitation,
    GuestGroupMembership,
)
from app.repositories.guest import GuestRepository
from app.schemas.guest import (
    GuestGroupCreate,
    GuestGroupEntryCreate,
    GuestGroupEntryUpdate,
    GuestInvitationCreate,
    GuestMemberRoleUpdate,
)

GUEST_GROUP_TTL = timedelta(days=90)
MAX_GUEST_GROUPS_PER_IDENTITY = 3
MAX_GUEST_GROUP_MEMBERS = 50
MAX_GUEST_GROUP_ENTRIES = 200
MAX_GUEST_ENTRY_BYTES = 256 * 1024
MAX_GUEST_GROUP_BYTES = 5 * 1024 * 1024
MAX_GUEST_ENTRY_REVISIONS = 100
MAX_ACTIVE_INVITATIONS = 20

GUEST_RATE_LIMITS: dict[str, tuple[int, int]] = {
    "create_group": (3, 60 * 60),
    "create_invitation": (20, 60 * 60),
    "join_invitation": (10, 60 * 60),
    "preview_invitation": (30, 60 * 60),
    "search": (60, 60),
    "read": (120, 60),
    "export": (10, 60 * 60),
    "write": (30, 60),
    "member_action": (30, 60),
}

_WRITE_ROLES = {"admin", "editor", "contributor"}
_EDIT_ANY_ROLES = {"admin", "editor"}


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _serialize(data: dict[str, Any]) -> tuple[dict[str, Any], int]:
    try:
        encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Guest content must be JSON data") from None
    size = len(encoded.encode("utf-8"))
    if size > MAX_GUEST_ENTRY_BYTES:
        raise HTTPException(status_code=413, detail="Guest entry exceeds the size limit")
    return json.loads(encoded), size


def _entry_dict(entry: GuestGroupEntry) -> dict[str, Any]:
    return {
        "id": entry.id,
        "kind": entry.kind,
        "title": entry.title,
        "data": entry.data,
        "revision": entry.revision,
        "created_by_uid": entry.created_by_uid,
        "updated_by_uid": entry.updated_by_uid,
        "client_import_key": entry.client_import_key,
    }


def _require_explicit_session_sharing(payload: GuestGroupEntryCreate) -> None:
    if payload.kind == "interact_session" and not payload.share_with_group:
        raise HTTPException(
            status_code=422,
            detail="Confirm sharing this Interact session with the guest group.",
        )


class GuestService:
    def __init__(self, session: AsyncSession) -> None:
        self.guest = GuestRepository(session)

    async def _rate_limit(self, firebase_uid: str, action: str) -> None:
        limit, window_seconds = GUEST_RATE_LIMITS[action]
        if not await self.guest.record_rate_limit(
            firebase_uid, action, limit, window_seconds
        ):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Guest request limit reached; retry after the current time window.",
                headers={"Retry-After": str(window_seconds)},
            )

    async def _group(
        self,
        group_id: UUID,
        firebase_uid: str,
        *,
        admin: bool = False,
        lock: bool = True,
    ) -> tuple[GuestGroup, GuestGroupMembership]:
        group = await self.guest.group(group_id, lock=lock)
        now = datetime.now(timezone.utc)
        if group is None or _utc(group.expires_at) <= now:
            raise HTTPException(status_code=404, detail="Guest group not found")
        member = await self.guest.member(
            group_id, firebase_uid, status="active"
        )
        if member is None:
            raise HTTPException(status_code=404, detail="Guest group not found")
        if admin and member.role != "admin":
            raise HTTPException(status_code=403, detail="Guest group administrator required")
        group.expires_at = now + GUEST_GROUP_TTL
        return group, member

    async def _member_can_write(self, group_id: UUID, firebase_uid: str) -> tuple[
        GuestGroup, GuestGroupMembership
    ]:
        group, member = await self._group(group_id, firebase_uid)
        if member.role not in _WRITE_ROLES:
            raise HTTPException(status_code=403, detail="Guest group is read-only")
        return group, member

    async def create_group(
        self, firebase_uid: str, payload: GuestGroupCreate
    ) -> dict[str, Any]:
        await self._rate_limit(firebase_uid, "create_group")
        count = await self.guest.created_group_count(firebase_uid)
        if count >= MAX_GUEST_GROUPS_PER_IDENTITY:
            raise HTTPException(status_code=429, detail="Guest group creation limit reached")
        now = datetime.now(timezone.utc)
        group = GuestGroup(
            name=payload.name.strip(),
            created_by_uid=firebase_uid,
            expires_at=now + GUEST_GROUP_TTL,
        )
        self.guest.add(group)
        await self.guest.flush()
        member = GuestGroupMembership(
            group_id=group.id,
            firebase_uid=firebase_uid,
            display_name=payload.display_name.strip(),
            role="admin",
            status="active",
            approved_by_uid=firebase_uid,
        )
        self.guest.add(member)
        await self.guest.commit()
        return self._group_dict(group, member)

    @staticmethod
    def _group_dict(group: GuestGroup, member: GuestGroupMembership) -> dict[str, Any]:
        return {
            "id": group.id,
            "name": group.name,
            "role": member.role,
            "expires_at": group.expires_at.isoformat(),
        }

    async def list_groups(self, firebase_uid: str) -> list[dict[str, Any]]:
        await self._rate_limit(firebase_uid, "read")
        now = datetime.now(timezone.utc)
        rows = await self.guest.groups_for_member(firebase_uid, now)
        for group, _member in rows:
            group.expires_at = now + GUEST_GROUP_TTL
        groups = [self._group_dict(group, member) for group, member in rows]
        await self.guest.commit()
        return groups

    async def get_group(
        self, group_id: UUID, firebase_uid: str
    ) -> dict[str, Any]:
        group, member = await self._group(group_id, firebase_uid, lock=False)
        members = await self.guest.members(
            group_id,
            statuses=("active", "pending") if member.role == "admin" else ("active",),
        )
        await self.guest.commit()
        return {
            **self._group_dict(group, member),
            "members": [
                {
                    "id": item.id,
                    "display_name": item.display_name,
                    "role": item.role,
                    "status": item.status,
                }
                for item in members
            ],
        }

    async def create_invitation(
        self,
        group_id: UUID,
        firebase_uid: str,
        payload: GuestInvitationCreate,
    ) -> dict[str, Any]:
        group, _ = await self._group(group_id, firebase_uid, admin=True)
        await self._rate_limit(firebase_uid, "create_invitation")
        now = datetime.now(timezone.utc)
        count = await self.guest.active_invitation_count(group_id, now)
        if count >= MAX_ACTIVE_INVITATIONS:
            raise HTTPException(status_code=429, detail="Guest invitation limit reached")
        token = secrets.token_urlsafe(32)
        invitation = GuestGroupInvitation(
            group_id=group_id,
            token_hash=hashlib.sha256(token.encode()).hexdigest(),
            role=payload.role,
            created_by_uid=firebase_uid,
            expires_at=now + timedelta(hours=payload.expires_in_hours),
        )
        self.guest.add(invitation)
        group.expires_at = now + GUEST_GROUP_TTL
        await self.guest.commit()
        return {
            "id": invitation.id,
            "token": token,
            "expires_at": invitation.expires_at.isoformat(),
        }

    async def list_invitations(
        self, group_id: UUID, firebase_uid: str
    ) -> list[dict[str, Any]]:
        await self._group(group_id, firebase_uid, admin=True, lock=False)
        await self._rate_limit(firebase_uid, "read")
        invitations = await self.guest.active_invitations(
            group_id, datetime.now(timezone.utc)
        )
        await self.guest.commit()
        return [
            {
                "id": invitation.id,
                "role": invitation.role,
                "expires_at": invitation.expires_at.isoformat(),
            }
            for invitation in invitations
        ]

    async def _invitation(self, token: str) -> GuestGroupInvitation | None:
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        invitation = await self.guest.invitation(token_hash)
        now = datetime.now(timezone.utc)
        if (
            invitation is None
            or invitation.revoked_at is not None
            or _utc(invitation.expires_at) <= now
        ):
            return None
        return invitation

    async def preview_invitation(
        self, firebase_uid: str, token: str
    ) -> dict[str, bool]:
        await self._rate_limit(firebase_uid, "preview_invitation")
        invitation = await self._invitation(token)
        await self.guest.commit()
        return {"valid": invitation is not None}

    async def join_invitation(
        self,
        firebase_uid: str,
        token: str,
        display_name: str,
    ) -> dict[str, Any]:
        await self._rate_limit(firebase_uid, "join_invitation")
        invitation = await self._invitation(token)
        if invitation is None:
            raise HTTPException(status_code=404, detail="Invitation is unavailable")
        group = await self.guest.group(invitation.group_id, lock=True)
        if group is None or _utc(group.expires_at) <= datetime.now(timezone.utc):
            raise HTTPException(status_code=404, detail="Invitation is unavailable")
        existing = await self.guest.member(
            invitation.group_id, firebase_uid, lock=True
        )
        if invitation.redeemed_by_uid is not None:
            if invitation.redeemed_by_uid == firebase_uid and existing is not None:
                if existing.status == "pending":
                    await self.guest.commit()
                    return self._member_dict(existing)
            raise HTTPException(status_code=409, detail="Invitation has already been used")
        count = await self.guest.member_count(invitation.group_id)
        if count >= MAX_GUEST_GROUP_MEMBERS:
            raise HTTPException(status_code=429, detail="Guest group member limit reached")
        if existing is not None and existing.status != "removed":
            raise HTTPException(status_code=409, detail="Already a member or awaiting approval")
        invitation.redeemed_by_uid = firebase_uid
        if existing is None:
            existing = GuestGroupMembership(
                group_id=invitation.group_id,
                firebase_uid=firebase_uid,
                display_name=display_name.strip(),
                role=invitation.role,
                status="pending",
            )
            self.guest.add(existing)
        else:
            existing.display_name = display_name.strip()
            existing.role = invitation.role
            existing.status = "pending"
            existing.approved_by_uid = None
        group.expires_at = datetime.now(timezone.utc) + GUEST_GROUP_TTL
        await self.guest.commit()
        return self._member_dict(existing)

    @staticmethod
    def _member_dict(member: GuestGroupMembership) -> dict[str, Any]:
        return {
            "id": member.id,
            "display_name": member.display_name,
            "role": member.role,
            "status": member.status,
        }

    async def revoke_invitation(
        self, group_id: UUID, invitation_id: UUID, firebase_uid: str
    ) -> None:
        await self._rate_limit(firebase_uid, "member_action")
        await self._group(group_id, firebase_uid, admin=True)
        invitation = await self.guest.invitation_by_id(group_id, invitation_id)
        if invitation is None:
            raise HTTPException(status_code=404, detail="Invitation not found")
        invitation.revoked_at = datetime.now(timezone.utc)
        await self.guest.commit()

    async def approve_member(
        self, group_id: UUID, member_id: UUID, firebase_uid: str
    ) -> dict[str, Any]:
        await self._rate_limit(firebase_uid, "member_action")
        await self._group(group_id, firebase_uid, admin=True)
        member = await self.guest.member_by_id(
            group_id, member_id, statuses=("pending",), lock=True
        )
        if member is None:
            raise HTTPException(status_code=404, detail="Pending guest member not found")
        member.status = "active"
        member.approved_by_uid = firebase_uid
        await self.guest.commit()
        return self._member_dict(member)

    async def update_member_role(
        self,
        group_id: UUID,
        member_id: UUID,
        firebase_uid: str,
        payload: GuestMemberRoleUpdate,
    ) -> dict[str, Any]:
        await self._rate_limit(firebase_uid, "member_action")
        await self._group(group_id, firebase_uid, admin=True)
        member = await self.guest.member_by_id(
            group_id, member_id, statuses=("active",), lock=True
        )
        if member is None or member.role == "admin":
            raise HTTPException(status_code=404, detail="Guest member not found")
        member.role = payload.role
        await self.guest.commit()
        return self._member_dict(member)

    async def remove_member(
        self, group_id: UUID, member_id: UUID, firebase_uid: str
    ) -> None:
        await self._rate_limit(firebase_uid, "member_action")
        await self._group(group_id, firebase_uid, admin=True)
        member = await self.guest.member_by_id(
            group_id, member_id, lock=True
        )
        if member is None or member.role == "admin":
            raise HTTPException(status_code=404, detail="Guest member not found")
        member.status = "removed"
        await self.guest.commit()

    async def transfer_administration(
        self, group_id: UUID, member_id: UUID, firebase_uid: str
    ) -> dict[str, Any]:
        await self._rate_limit(firebase_uid, "member_action")
        _, current_admin = await self._group(group_id, firebase_uid, admin=True)
        target = await self.guest.member_by_id(
            group_id, member_id, statuses=("active",), lock=True
        )
        if target is None or target.id == current_admin.id:
            raise HTTPException(status_code=404, detail="Active guest member not found")
        current_admin.role = "contributor"
        target.role = "admin"
        target.approved_by_uid = firebase_uid
        await self.guest.commit()
        return self._member_dict(target)

    async def search_entries(
        self,
        group_id: UUID,
        firebase_uid: str,
        query: str,
        *,
        kind: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        group, _ = await self._group(group_id, firebase_uid, lock=False)
        await self._rate_limit(firebase_uid, "search")
        if len(query) > 200:
            raise HTTPException(status_code=422, detail="Search query is too long")
        entries = await self.guest.entries(
            group_id, kind=kind, limit=MAX_GUEST_GROUP_ENTRIES
        )
        words = query.casefold().split()
        if words:
            entries = [
                entry
                for entry in entries
                if _matches_query(words, entry.title, entry.data)
            ]
        result = [_entry_dict(entry) for entry in entries[:limit]]
        group.expires_at = datetime.now(timezone.utc) + GUEST_GROUP_TTL
        await self.guest.commit()
        return result

    async def create_entry(
        self,
        group_id: UUID,
        firebase_uid: str,
        payload: GuestGroupEntryCreate,
    ) -> dict[str, Any]:
        group, member = await self._member_can_write(group_id, firebase_uid)
        await self._rate_limit(firebase_uid, "write")
        if payload.client_import_key:
            existing = await self.guest.entry_for_import(
                group_id, firebase_uid, payload.client_import_key
            )
            if existing is not None:
                await self.guest.commit()
                return _entry_dict(existing)
        count = await self.guest.entry_count(group_id)
        if count >= MAX_GUEST_GROUP_ENTRIES:
            raise HTTPException(status_code=429, detail="Guest group storage limit reached")
        _require_explicit_session_sharing(payload)
        data, size = _serialize(payload.data)
        title = payload.title.strip()
        await self._check_group_storage(group_id, size + len(title.encode("utf-8")))
        entry = GuestGroupEntry(
            group_id=group_id,
            kind=payload.kind,
            title=title,
            data=data,
            created_by_uid=firebase_uid,
            updated_by_uid=firebase_uid,
            client_import_key=payload.client_import_key,
            revision=1,
        )
        self.guest.add(entry)
        group.expires_at = datetime.now(timezone.utc) + GUEST_GROUP_TTL
        await self.guest.commit()
        return _entry_dict(entry)

    async def import_entries(
        self,
        group_id: UUID,
        firebase_uid: str,
        entries: list[GuestGroupEntryCreate],
    ) -> list[dict[str, Any]]:
        group, _ = await self._member_can_write(group_id, firebase_uid)
        await self._rate_limit(firebase_uid, "write")
        results = []
        for payload in entries:
            if not payload.client_import_key:
                raise HTTPException(
                    status_code=422,
                    detail="Each imported entry requires an idempotency key",
                )
            existing = await self.guest.entry_for_import(
                group_id, firebase_uid, payload.client_import_key
            )
            if existing is not None:
                results.append(_entry_dict(existing))
                continue
            count = await self.guest.entry_count(group_id)
            if count >= MAX_GUEST_GROUP_ENTRIES:
                raise HTTPException(
                    status_code=429, detail="Guest group storage limit reached"
                )
            data, size = _serialize(payload.data)
            _require_explicit_session_sharing(payload)
            title = payload.title.strip()
            await self._check_group_storage(group_id, size + len(title.encode("utf-8")))
            entry = GuestGroupEntry(
                group_id=group_id,
                kind=payload.kind,
                title=title,
                data=data,
                created_by_uid=firebase_uid,
                updated_by_uid=firebase_uid,
                client_import_key=payload.client_import_key,
                revision=1,
            )
            self.guest.add(entry)
            await self.guest.flush()
            results.append(_entry_dict(entry))
        group.expires_at = datetime.now(timezone.utc) + GUEST_GROUP_TTL
        await self.guest.commit()
        return results

    async def _check_group_storage(self, group_id: UUID, new_size: int) -> None:
        current_size = await self.guest.group_content_size(group_id)
        if current_size + new_size > MAX_GUEST_GROUP_BYTES:
            raise HTTPException(status_code=413, detail="Guest group storage limit reached")

    async def get_entry(
        self, group_id: UUID, entry_id: UUID, firebase_uid: str
    ) -> dict[str, Any]:
        _, _ = await self._group(group_id, firebase_uid, lock=False)
        await self._rate_limit(firebase_uid, "read")
        entry = await self._entry(group_id, entry_id)
        await self.guest.commit()
        return _entry_dict(entry)

    async def update_entry(
        self,
        group_id: UUID,
        entry_id: UUID,
        firebase_uid: str,
        payload: GuestGroupEntryUpdate,
    ) -> dict[str, Any]:
        group, member = await self._member_can_write(group_id, firebase_uid)
        await self._rate_limit(firebase_uid, "write")
        entry = await self._entry(group_id, entry_id, lock=True)
        if member.role not in _EDIT_ANY_ROLES and entry.created_by_uid != firebase_uid:
            raise HTTPException(status_code=403, detail="Cannot edit another member's content")
        if payload.title is None and payload.data is None:
            raise HTTPException(status_code=422, detail="No guest content changes supplied")
        title = payload.title.strip() if payload.title is not None else entry.title
        data, size = _serialize(payload.data if payload.data is not None else entry.data)
        await self._check_group_storage(group_id, size + len(title.encode("utf-8")))
        if entry.revision >= MAX_GUEST_ENTRY_REVISIONS:
            raise HTTPException(
                status_code=429, detail="Guest content revision limit reached"
            )
        self.guest.add(
            GuestGroupEntryRevision(
                entry_id=entry.id,
                edited_by_uid=firebase_uid,
                title=entry.title,
                data=entry.data,
                revision=entry.revision,
            )
        )
        entry.title = title
        entry.data = data
        entry.updated_by_uid = firebase_uid
        entry.revision += 1
        group.expires_at = datetime.now(timezone.utc) + GUEST_GROUP_TTL
        await self.guest.commit()
        return _entry_dict(entry)

    async def delete_entry(
        self, group_id: UUID, entry_id: UUID, firebase_uid: str
    ) -> None:
        _, member = await self._member_can_write(group_id, firebase_uid)
        await self._rate_limit(firebase_uid, "write")
        entry = await self._entry(group_id, entry_id, lock=True)
        if member.role not in _EDIT_ANY_ROLES and entry.created_by_uid != firebase_uid:
            raise HTTPException(status_code=403, detail="Cannot remove another member's content")
        await self.guest.delete(entry)
        await self.guest.commit()

    async def entry_history(
        self, group_id: UUID, entry_id: UUID, firebase_uid: str
    ) -> list[dict[str, Any]]:
        await self._group(group_id, firebase_uid, lock=False)
        await self._rate_limit(firebase_uid, "read")
        entry = await self._entry(group_id, entry_id)
        revisions = await self.guest.entry_revisions(entry.id)
        result = [
            {
                "revision": item.revision,
                "title": item.title,
                "data": item.data,
                "edited_by_uid": item.edited_by_uid,
            }
            for item in revisions
        ]
        result.append(
            {
                "revision": entry.revision,
                "title": entry.title,
                "data": entry.data,
                "edited_by_uid": entry.updated_by_uid,
            }
        )
        await self.guest.commit()
        return result

    async def export_entry(
        self, group_id: UUID, entry_id: UUID, firebase_uid: str
    ) -> dict[str, Any]:
        await self._group(group_id, firebase_uid, lock=False)
        await self._rate_limit(firebase_uid, "export")
        entry = await self._entry(group_id, entry_id)
        await self.guest.commit()
        return _entry_dict(entry)

    async def _entry(
        self, group_id: UUID, entry_id: UUID, *, lock: bool = False
    ) -> GuestGroupEntry:
        entry = await self.guest.entry(group_id, entry_id, lock=lock)
        if entry is None:
            raise HTTPException(status_code=404, detail="Guest content not found")
        return entry

    async def revoke_group(
        self, group_id: UUID, firebase_uid: str
    ) -> None:
        await self._rate_limit(firebase_uid, "member_action")
        group, _ = await self._group(group_id, firebase_uid, admin=True)
        group.expires_at = datetime.now(timezone.utc)
        await self.guest.commit()


def _matches_query(words: list[str], title: str, data: dict[str, Any]) -> bool:
    text = " ".join([title, *_strings(data)]).casefold()
    candidates = text.replace("/", " ").replace("-", " ").split()
    return all(
        token in text or any(candidate.startswith(token) for candidate in candidates)
        for token in words
    )


def _strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [part for item in value.values() for part in _strings(item)]
    if isinstance(value, list):
        return [part for item in value for part in _strings(item)]
    return []
