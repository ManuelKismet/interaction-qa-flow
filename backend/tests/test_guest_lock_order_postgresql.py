import asyncio
import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from app.models.guest import (
    GuestActionRateLimit,
    GuestGroup,
    GuestGroupInvitation,
    GuestGroupMembership,
)
from app.repositories.guest import GuestRepository
from app.services.guest import GuestService
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine


@pytest.mark.asyncio
async def test_list_groups_and_invitations_share_rate_before_group_lock(
    monkeypatch,
) -> None:
    database_url = os.environ.get("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is not configured")

    engine = create_async_engine(database_url)
    schema_name = f"guest_lock_test_{uuid4().hex}"
    async with engine.begin() as connection:
        await connection.execute(text(f'CREATE SCHEMA "{schema_name}"'))
        await connection.execute(text(f'SET search_path TO "{schema_name}", public'))
        await connection.run_sync(
            lambda sync_connection: GuestGroup.metadata.create_all(
                sync_connection,
                tables=[
                    GuestGroup.__table__,
                    GuestGroupMembership.__table__,
                    GuestGroupInvitation.__table__,
                    GuestActionRateLimit.__table__,
                ],
            )
        )

    @event.listens_for(engine.sync_engine, "connect")
    def set_test_schema(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute(f'SET search_path TO "{schema_name}", public')
        cursor.close()

    try:
        session_factory = async_sessionmaker(engine, expire_on_commit=False)
        group_id = uuid4()
        firebase_uid = f"lock-order-{uuid4().hex}"
        async with session_factory() as session:
            session.add(
                GuestGroup(
                    id=group_id,
                    name="Lock ordering",
                    created_by_uid=firebase_uid,
                    expires_at=datetime.now(timezone.utc) + timedelta(days=30),
                )
            )
            session.add(
                GuestGroupMembership(
                    group_id=group_id,
                    firebase_uid=firebase_uid,
                    display_name="Tester",
                    role="admin",
                    status="active",
                    approved_by_uid=firebase_uid,
                )
            )
            await session.commit()

        groups_rate_held = asyncio.Event()
        allow_groups_to_continue = asyncio.Event()
        invitations_at_rate_limit = asyncio.Event()
        original_record_rate_limit = GuestRepository.record_rate_limit

        async def instrumented_record_rate_limit(
            repository: GuestRepository,
            uid: str,
            action: str,
            limit: int,
            window_seconds: int,
        ) -> bool:
            task_name = asyncio.current_task().get_name()
            if uid == firebase_uid and action == "read":
                # Match the autoflush performed by the rate-limit upsert when a
                # prior group read has refreshed expires_at.
                await repository.session.flush()
                if task_name == "list_groups":
                    result = await original_record_rate_limit(
                        repository, uid, action, limit, window_seconds
                    )
                    groups_rate_held.set()
                    await allow_groups_to_continue.wait()
                    return result
                if task_name == "list_invitations":
                    invitations_at_rate_limit.set()
            return await original_record_rate_limit(
                repository, uid, action, limit, window_seconds
            )

        monkeypatch.setattr(
            GuestRepository, "record_rate_limit", instrumented_record_rate_limit
        )

        async def list_groups() -> list[dict]:
            async with session_factory() as session:
                await session.execute(text("SET LOCAL lock_timeout = '3s'"))
                return await GuestService(session).list_groups(firebase_uid)

        async def list_invitations() -> list[dict]:
            async with session_factory() as session:
                await session.execute(text("SET LOCAL lock_timeout = '3s'"))
                return await GuestService(session).list_invitations(
                    group_id, firebase_uid
                )

        groups_task = asyncio.create_task(list_groups(), name="list_groups")
        await asyncio.wait_for(groups_rate_held.wait(), timeout=3)
        invitations_task = asyncio.create_task(
            list_invitations(), name="list_invitations"
        )
        await asyncio.wait_for(invitations_at_rate_limit.wait(), timeout=3)
        allow_groups_to_continue.set()

        groups, invitations = await asyncio.wait_for(
            asyncio.gather(groups_task, invitations_task), timeout=8
        )
        assert [group["id"] for group in groups] == [group_id]
        assert invitations == []
    finally:
        event.remove(engine.sync_engine, "connect", set_test_schema)
        async with engine.begin() as connection:
            await connection.execute(
                text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
            )
        await engine.dispose()
