import argparse
import asyncio
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import async_session_factory
from app.models.guest import (
    GuestGroup,
    GuestGroupEntry,
    GuestGroupEntryRevision,
    GuestGroupInvitation,
    GuestGroupMembership,
)

MAX_BATCH_SIZE = 500
DEFAULT_BATCH_SIZE = 100


@dataclass
class RetentionCounts:
    groups: int = 0
    memberships: int = 0
    invitations: int = 0
    entries: int = 0
    revisions: int = 0

    def add(self, other: "RetentionCounts") -> None:
        self.groups += other.groups
        self.memberships += other.memberships
        self.invitations += other.invitations
        self.entries += other.entries
        self.revisions += other.revisions

    def as_dict(self) -> dict[str, int]:
        return {
            "groups": self.groups,
            "memberships": self.memberships,
            "invitations": self.invitations,
            "entries": self.entries,
            "revisions": self.revisions,
        }


async def _purge_candidate(
    session_factory: async_sessionmaker[AsyncSession],
    group_id: UUID,
    cutoff: datetime,
    *,
    apply: bool,
) -> RetentionCounts | None:
    async with session_factory() as session:
        async with session.begin():
            group = await session.scalar(
                select(GuestGroup)
                .where(
                    GuestGroup.id == group_id,
                    GuestGroup.archived_at.is_(None),
                )
                .with_for_update()
            )
            if (
                group is None
                or group.archived_at is not None
                or _utc(group.expires_at) > cutoff
            ):
                return None

            counts = await _group_counts(session, group_id)
            counts.groups = 1
            if apply:
                entry_ids = select(GuestGroupEntry.id).where(
                    GuestGroupEntry.group_id == group_id
                )
                await session.execute(
                    delete(GuestGroupEntryRevision).where(
                        GuestGroupEntryRevision.entry_id.in_(entry_ids)
                    )
                )
                await session.execute(
                    delete(GuestGroupEntry).where(
                        GuestGroupEntry.group_id == group_id
                    )
                )
                await session.execute(
                    delete(GuestGroupInvitation).where(
                        GuestGroupInvitation.group_id == group_id
                    )
                )
                await session.execute(
                    delete(GuestGroupMembership).where(
                        GuestGroupMembership.group_id == group_id
                    )
                )
                await session.execute(
                    delete(GuestGroup).where(GuestGroup.id == group_id)
                )
            return counts


async def _group_counts(session: AsyncSession, group_id: UUID) -> RetentionCounts:
    entries = select(GuestGroupEntry.id).where(GuestGroupEntry.group_id == group_id)
    revisions = (
        select(func.count(GuestGroupEntryRevision.id))
        .where(GuestGroupEntryRevision.entry_id.in_(entries))
    )
    return RetentionCounts(
        memberships=await _count(
            session,
            select(func.count(GuestGroupMembership.id)).where(
                GuestGroupMembership.group_id == group_id
            ),
        ),
        invitations=await _count(
            session,
            select(func.count(GuestGroupInvitation.id)).where(
                GuestGroupInvitation.group_id == group_id
            ),
        ),
        entries=await _count(session, select(func.count()).select_from(entries.subquery())),
        revisions=await _count(session, revisions),
    )


async def _count(session: AsyncSession, statement) -> int:
    return int(await session.scalar(statement) or 0)


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


async def cleanup_expired_guest_groups(
    session_factory: async_sessionmaker[AsyncSession],
    *,
    cutoff: datetime | None = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
    apply: bool = False,
) -> dict[str, object]:
    if not 1 <= batch_size <= MAX_BATCH_SIZE:
        raise ValueError(f"batch_size must be between 1 and {MAX_BATCH_SIZE}")
    cutoff = cutoff or datetime.now(timezone.utc)
    async with session_factory() as session:
        candidate_ids = list(
            await session.scalars(
                select(GuestGroup.id)
                .where(
                    GuestGroup.expires_at <= cutoff,
                    GuestGroup.archived_at.is_(None),
                )
                .order_by(GuestGroup.expires_at, GuestGroup.id)
                .limit(batch_size + 1)
            )
        )
    has_more = len(candidate_ids) > batch_size
    candidate_ids = candidate_ids[:batch_size]

    eligible = RetentionCounts()
    for group_id in candidate_ids:
        counts = await _purge_candidate(
            session_factory, group_id, cutoff, apply=apply
        )
        if counts is not None:
            eligible.add(counts)

    deleted = eligible.as_dict() if apply else RetentionCounts().as_dict()
    return {
        "mode": "apply" if apply else "dry-run",
        "candidate_groups": len(candidate_ids),
        "has_more": has_more,
        "eligible": eligible.as_dict(),
        "deleted": deleted,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Review or remove expired shared guest groups."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="delete eligible groups; without this flag, only report counts",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help=f"maximum groups to inspect (1-{MAX_BATCH_SIZE}; default {DEFAULT_BATCH_SIZE})",
    )
    args = parser.parse_args()
    result = asyncio.run(
        cleanup_expired_guest_groups(
            async_session_factory,
            batch_size=args.batch_size,
            apply=args.apply,
        )
    )
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
