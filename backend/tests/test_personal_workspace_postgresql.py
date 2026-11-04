import asyncio
import os
from uuid import uuid4

import pytest
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.models.personal_workspace import PersonalWorkspaceItem
from app.schemas.personal_workspace import PersonalWorkspaceItemInput
from app.services.personal_workspace import PersonalWorkspaceService


@pytest.mark.asyncio
async def test_overlapping_reverse_order_personal_imports_do_not_deadlock() -> None:
    database_url = os.environ.get("POSTGRES_TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is not configured")

    engine = create_async_engine(database_url)
    schema_name = f"personal_workspace_test_{uuid4().hex}"

    def set_test_schema(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute(f'SET search_path TO "{schema_name}", public')
        cursor.close()

    event.listen(engine.sync_engine, "connect", set_test_schema)
    try:
        async with engine.begin() as connection:
            await connection.execute(text(f'CREATE SCHEMA "{schema_name}"'))
            await connection.execute(
                text(f'SET search_path TO "{schema_name}", public')
            )
            await connection.run_sync(PersonalWorkspaceItem.__table__.create)

        session_factory = async_sessionmaker(engine, expire_on_commit=False)
        firebase_uid = f"overlap-{uuid4().hex}"
        entries = [
            PersonalWorkspaceItemInput(
                kind="knowledge",
                source_key=f"knowledge:{item_id}",
                title=f"Item {item_id}",
                data={
                    "id": item_id,
                    "title": f"Item {item_id}",
                    "answer": item_id,
                },
            )
            for item_id in ("a", "b")
        ]
        ready = 0
        both_ready = asyncio.Event()
        start = asyncio.Event()

        async def import_batch(batch: list[PersonalWorkspaceItemInput]) -> dict:
            nonlocal ready
            async with session_factory() as session:
                await session.execute(text("SET LOCAL lock_timeout = '5s'"))
                ready += 1
                if ready == 2:
                    both_ready.set()
                await start.wait()
                return await PersonalWorkspaceService(session).import_items(
                    firebase_uid, batch
                )

        first_task = asyncio.create_task(import_batch(entries))
        second_task = asyncio.create_task(import_batch(list(reversed(entries))))
        await asyncio.wait_for(both_ready.wait(), timeout=3)
        start.set()
        first, second = await asyncio.wait_for(
            asyncio.gather(first_task, second_task),
            timeout=10,
        )

        assert [item["source_key"] for item in first["items"]] == [
            item.source_key for item in entries
        ]
        assert [item["source_key"] for item in second["items"]] == [
            item.source_key for item in reversed(entries)
        ]
        assert sum(first["created"] + second["created"]) == 2
    finally:
        event.remove(engine.sync_engine, "connect", set_test_schema)
        async with engine.begin() as connection:
            await connection.execute(
                text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE')
            )
        await engine.dispose()
