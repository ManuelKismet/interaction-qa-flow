import json
import time
from datetime import datetime
from uuid import UUID

from sqlalchemy import case, func, or_, select
from sqlalchemy.dialects.postgresql import insert as postgres_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.guest import (
    GuestActionRateLimit,
    GuestGroup,
    GuestGroupEntry,
    GuestGroupEntryRevision,
    GuestGroupInvitation,
    GuestGroupMembership,
)


class GuestRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def record_rate_limit(
        self,
        firebase_uid: str,
        action: str,
        limit: int,
        window_seconds: int,
    ) -> bool:
        now = int(time.time())
        window_start = now // window_seconds * window_seconds
        table = GuestActionRateLimit.__table__
        dialect = self.session.get_bind().dialect.name
        insert = (
            postgres_insert(table)
            if dialect == "postgresql"
            else sqlite_insert(table)
            if dialect == "sqlite"
            else None
        )
        if insert is None:
            raise RuntimeError(f"Guest rate limits are not configured for {dialect}")
        statement = insert.values(
            firebase_uid=firebase_uid,
            action=action,
            window_start=window_start,
            hits=1,
        )
        excluded = statement.excluded
        statement = statement.on_conflict_do_update(
            index_elements=[table.c.firebase_uid, table.c.action],
            set_={
                "window_start": excluded.window_start,
                "hits": case(
                    (table.c.window_start == excluded.window_start, table.c.hits + 1),
                    else_=1,
                ),
            },
            where=or_(
                table.c.window_start != excluded.window_start,
                table.c.hits < limit,
            ),
        ).returning(table.c.hits)
        result = await self.session.execute(statement)
        return result.scalar_one_or_none() is not None

    async def group(
        self, group_id: UUID, *, lock: bool = False
    ) -> GuestGroup | None:
        statement = select(GuestGroup).where(GuestGroup.id == group_id)
        if lock:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)

    async def member(
        self,
        group_id: UUID,
        firebase_uid: str,
        *,
        status: str | None = None,
        lock: bool = False,
    ) -> GuestGroupMembership | None:
        statement = select(GuestGroupMembership).where(
            GuestGroupMembership.group_id == group_id,
            GuestGroupMembership.firebase_uid == firebase_uid,
        )
        if status is not None:
            statement = statement.where(GuestGroupMembership.status == status)
        if lock:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)

    async def member_by_id(
        self,
        group_id: UUID,
        member_id: UUID,
        *,
        statuses: tuple[str, ...] | None = None,
        lock: bool = False,
    ) -> GuestGroupMembership | None:
        statement = select(GuestGroupMembership).where(
            GuestGroupMembership.id == member_id,
            GuestGroupMembership.group_id == group_id,
        )
        if statuses is not None:
            statement = statement.where(GuestGroupMembership.status.in_(statuses))
        if lock:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)

    async def members(
        self, group_id: UUID, *, statuses: tuple[str, ...]
    ) -> list[GuestGroupMembership]:
        rows = await self.session.scalars(
            select(GuestGroupMembership).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.status.in_(statuses),
            )
        )
        return list(rows)

    async def created_group_count(self, firebase_uid: str) -> int:
        return await self.session.scalar(
            select(func.count(GuestGroup.id)).where(
                GuestGroup.created_by_uid == firebase_uid
            )
        ) or 0

    async def groups_for_member(
        self, firebase_uid: str, now: datetime
    ) -> list[tuple[GuestGroup, GuestGroupMembership]]:
        result = await self.session.execute(
            select(GuestGroup, GuestGroupMembership)
            .join(
                GuestGroupMembership,
                GuestGroupMembership.group_id == GuestGroup.id,
            )
            .where(
                GuestGroupMembership.firebase_uid == firebase_uid,
                GuestGroupMembership.status == "active",
                GuestGroup.expires_at > now,
            )
            .order_by(GuestGroup.name)
        )
        return list(result.all())

    async def invitation(
        self, token_hash: str
    ) -> GuestGroupInvitation | None:
        return await self.session.scalar(
            select(GuestGroupInvitation).where(
                GuestGroupInvitation.token_hash == token_hash
            )
        )

    async def invitation_by_id(
        self, group_id: UUID, invitation_id: UUID
    ) -> GuestGroupInvitation | None:
        return await self.session.scalar(
            select(GuestGroupInvitation).where(
                GuestGroupInvitation.id == invitation_id,
                GuestGroupInvitation.group_id == group_id,
            )
        )

    async def active_invitation_count(self, group_id: UUID, now: datetime) -> int:
        return await self.session.scalar(
            select(func.count(GuestGroupInvitation.id)).where(
                GuestGroupInvitation.group_id == group_id,
                GuestGroupInvitation.revoked_at.is_(None),
                GuestGroupInvitation.expires_at > now,
                GuestGroupInvitation.redeemed_by_uid.is_(None),
            )
        ) or 0

    async def member_count(self, group_id: UUID) -> int:
        return await self.session.scalar(
            select(func.count(GuestGroupMembership.id)).where(
                GuestGroupMembership.group_id == group_id,
                GuestGroupMembership.status.in_(("active", "pending")),
            )
        ) or 0

    async def entry_count(self, group_id: UUID) -> int:
        return await self.session.scalar(
            select(func.count(GuestGroupEntry.id)).where(
                GuestGroupEntry.group_id == group_id
            )
        ) or 0

    async def entries(
        self,
        group_id: UUID,
        *,
        kind: str | None = None,
        limit: int | None = None,
    ) -> list[GuestGroupEntry]:
        statement = select(GuestGroupEntry).where(
            GuestGroupEntry.group_id == group_id
        )
        if kind is not None:
            statement = statement.where(GuestGroupEntry.kind == kind)
        statement = statement.order_by(GuestGroupEntry.updated_at.desc())
        if limit is not None:
            statement = statement.limit(limit)
        return list(await self.session.scalars(statement))

    async def entry_for_import(
        self, group_id: UUID, firebase_uid: str, import_key: str
    ) -> GuestGroupEntry | None:
        return await self.session.scalar(
            select(GuestGroupEntry).where(
                GuestGroupEntry.group_id == group_id,
                GuestGroupEntry.created_by_uid == firebase_uid,
                GuestGroupEntry.client_import_key == import_key,
            )
        )

    async def entry(
        self, group_id: UUID, entry_id: UUID, *, lock: bool = False
    ) -> GuestGroupEntry | None:
        statement = select(GuestGroupEntry).where(
            GuestGroupEntry.id == entry_id,
            GuestGroupEntry.group_id == group_id,
        )
        if lock:
            statement = statement.with_for_update()
        return await self.session.scalar(statement)

    async def entry_revisions(
        self, entry_id: UUID
    ) -> list[GuestGroupEntryRevision]:
        rows = await self.session.scalars(
            select(GuestGroupEntryRevision)
            .where(GuestGroupEntryRevision.entry_id == entry_id)
            .order_by(GuestGroupEntryRevision.revision)
        )
        return list(rows)

    def add(self, entity) -> None:
        self.session.add(entity)

    async def flush(self) -> None:
        await self.session.flush()

    async def commit(self) -> None:
        await self.session.commit()

    async def delete(self, entity) -> None:
        await self.session.delete(entity)

    async def group_content_size(self, group_id: UUID) -> int:
        entries = await self.session.scalars(
            select(GuestGroupEntry).where(GuestGroupEntry.group_id == group_id)
        )
        live_content_size = sum(
            len(item.title.encode("utf-8"))
            + len(
                json.dumps(
                    item.data,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ).encode("utf-8")
            )
            for item in entries
        )
        revisions = await self.session.scalars(
            select(GuestGroupEntryRevision)
            .join(
                GuestGroupEntry,
                GuestGroupEntry.id == GuestGroupEntryRevision.entry_id,
            )
            .where(GuestGroupEntry.group_id == group_id)
        )
        revision_content_size = sum(
            len(item.title.encode("utf-8"))
            + len(
                json.dumps(
                    item.data,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ).encode("utf-8")
            )
            for item in revisions
        )
        return live_content_size + revision_content_size
