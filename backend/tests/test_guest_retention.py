from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import pytest
from sqlalchemy import event, func, select

from app.maintenance import guest_retention
from app.models.guest import (
    GuestGroup,
    GuestGroupEntry,
    GuestGroupEntryRevision,
    GuestGroupInvitation,
    GuestGroupMembership,
)


async def _seed_group(session_factory, expires_at: datetime) -> UUID:
    group = GuestGroup(
        name="Synthetic group",
        created_by_uid=f"uid-{uuid4()}",
        expires_at=expires_at,
    )
    async with session_factory() as session:
        session.add(group)
        await session.flush()
        entry = GuestGroupEntry(
            group_id=group.id,
            kind="knowledge",
            title="Synthetic entry",
            data={"body": "synthetic"},
            created_by_uid=group.created_by_uid,
            updated_by_uid=group.created_by_uid,
        )
        session.add_all(
            [
                GuestGroupMembership(
                    group_id=group.id,
                    firebase_uid=group.created_by_uid,
                    display_name="Synthetic",
                    role="admin",
                    status="active",
                ),
                GuestGroupInvitation(
                    group_id=group.id,
                    token_hash=group.id.hex * 2,
                    role="viewer",
                    created_by_uid=group.created_by_uid,
                    expires_at=expires_at,
                ),
                entry,
            ]
        )
        await session.flush()
        session.add(
            GuestGroupEntryRevision(
                entry_id=entry.id,
                edited_by_uid=group.created_by_uid,
                title=entry.title,
                data=entry.data,
                revision=1,
            )
        )
        await session.commit()
        group_id = group.id
    return group_id


@pytest.mark.asyncio
async def test_expiry_boundary_dry_run_apply_batch_and_retry(app_client) -> None:
    _, session_factory = app_client
    now = datetime.now(timezone.utc)
    expired_id = await _seed_group(session_factory, now - timedelta(days=2))
    active_id = await _seed_group(session_factory, now + timedelta(microseconds=1))
    boundary_id = await _seed_group(session_factory, now)

    dry_run = await guest_retention.cleanup_expired_guest_groups(
        session_factory, cutoff=now, batch_size=1
    )
    assert dry_run == {
        "mode": "dry-run",
        "candidate_groups": 1,
        "has_more": True,
        "eligible": {
            "groups": 1,
            "memberships": 1,
            "invitations": 1,
            "entries": 1,
            "revisions": 1,
        },
        "deleted": {
            "groups": 0,
            "memberships": 0,
            "invitations": 0,
            "entries": 0,
            "revisions": 0,
        },
    }
    async with session_factory() as session:
        assert await session.get(GuestGroup, expired_id) is not None

    applied = await guest_retention.cleanup_expired_guest_groups(
        session_factory, cutoff=now, batch_size=1, apply=True
    )
    assert applied["deleted"]["groups"] == 1
    async with session_factory() as session:
        assert await session.get(GuestGroup, expired_id) is None
        assert await session.get(GuestGroup, active_id) is not None
        assert await session.get(GuestGroup, boundary_id) is not None

    retried = await guest_retention.cleanup_expired_guest_groups(
        session_factory, cutoff=now, batch_size=1, apply=True
    )
    assert retried["deleted"]["groups"] == 1
    repeated = await guest_retention.cleanup_expired_guest_groups(
        session_factory, cutoff=now, batch_size=1, apply=True
    )
    assert repeated["candidate_groups"] == 0


@pytest.mark.asyncio
async def test_rechecks_expiry_after_candidate_selection(app_client, monkeypatch) -> None:
    _, session_factory = app_client
    now = datetime.now(timezone.utc)
    group_id = await _seed_group(session_factory, now - timedelta(days=1))
    purge_candidate = guest_retention._purge_candidate
    reactivated = False

    async def reactivate_before_recheck(factory, candidate_id, cutoff, *, apply):
        nonlocal reactivated
        if not reactivated:
            reactivated = True
            async with factory() as session:
                group = await session.get(GuestGroup, candidate_id)
                group.expires_at = cutoff + timedelta(days=90)
                await session.commit()
        return await purge_candidate(factory, candidate_id, cutoff, apply=apply)

    monkeypatch.setattr(guest_retention, "_purge_candidate", reactivate_before_recheck)
    result = await guest_retention.cleanup_expired_guest_groups(
        session_factory, cutoff=now, apply=True
    )
    assert result["candidate_groups"] == 1
    assert result["eligible"]["groups"] == 0
    assert result["deleted"]["groups"] == 0
    async with session_factory() as session:
        assert await session.get(GuestGroup, group_id) is not None


@pytest.mark.asyncio
async def test_batch_limit_and_child_deletion_rollback(app_client) -> None:
    _, session_factory = app_client
    now = datetime.now(timezone.utc)
    group_id = await _seed_group(session_factory, now - timedelta(days=1))
    candidate_id = await _seed_group(session_factory, now - timedelta(days=2))
    with pytest.raises(ValueError, match="batch_size"):
        await guest_retention.cleanup_expired_guest_groups(
            session_factory, cutoff=now, batch_size=guest_retention.MAX_BATCH_SIZE + 1
        )

    engine = session_factory.kw["bind"]

    def fail_entry_delete(_conn, _cursor, statement, _parameters, _context, _many):
        if statement.startswith("DELETE FROM guest_group_entries"):
            raise RuntimeError("synthetic failure")

    event.listen(engine.sync_engine, "before_cursor_execute", fail_entry_delete)
    try:
        with pytest.raises(RuntimeError, match="synthetic failure"):
            await guest_retention.cleanup_expired_guest_groups(
                session_factory, cutoff=now, batch_size=1, apply=True
            )
    finally:
        event.remove(engine.sync_engine, "before_cursor_execute", fail_entry_delete)

    async with session_factory() as session:
        assert await session.get(GuestGroup, candidate_id) is not None
        assert await session.get(GuestGroup, group_id) is not None
        assert await session.scalar(
            select(func.count(GuestGroupMembership.id)).where(
                GuestGroupMembership.group_id == candidate_id
            )
        ) == 1
        assert await session.scalar(
            select(func.count(GuestGroupEntryRevision.id)).join(
                GuestGroupEntry,
                GuestGroupEntry.id == GuestGroupEntryRevision.entry_id,
            ).where(GuestGroupEntry.group_id == candidate_id)
        ) == 1
