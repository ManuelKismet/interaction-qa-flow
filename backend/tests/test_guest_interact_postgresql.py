import asyncio
from copy import deepcopy

import pytest
import pytest_asyncio
from sqlalchemy import func, select, text

from app.core.database import get_session
from app.main import app
from app.models.guest import GuestGroupEntry, GuestGroupEntryRevision
from app.repositories.guest import GuestRepository
from tests import test_guest_interact_edit as interact_tests
from tests.test_guest_groups import bearer, install_test_tokens, make_group
from tests.test_guest_interact_edit import add_member, interact_graph, share_interact
from tests.test_organisation_administration_postgres import postgres_sessions


@pytest_asyncio.fixture
async def postgres_client(app_client, postgres_sessions):
    client, _ = app_client

    async def isolated_session():
        async with postgres_sessions() as session:
            await session.execute(text("SET LOCAL lock_timeout = '5s'"))
            yield session

    app.dependency_overrides[get_session] = isolated_session
    yield client, postgres_sessions


@pytest.mark.asyncio
@pytest.mark.parametrize("first_uid", ["host", "editor"])
async def test_competing_interact_patches_lock_and_reject_stale_graph(
    postgres_client, monkeypatch, first_uid
) -> None:
    client, sessions = postgres_client
    install_test_tokens(monkeypatch)
    group = await make_group(client, "host", "Competing shared edits")
    await add_member(client, group["id"], "editor", "editor")
    entry = await share_interact(client, group["id"])
    path = f"/api/v1/guest/groups/{group['id']}/entries/{entry['id']}"
    graphs = {uid: deepcopy(interact_graph()) for uid in ("host", "editor")}
    for uid, graph in graphs.items():
        graph["questions"][0]["answers"][0]["body"] = f"{uid}'s competing answer"
        graph["questions"][0]["answers"][0]["follow_ups"][0]["text"] = f"{uid}'s follow-up"

    first_holds_lock = asyncio.Event()
    release_first = asyncio.Event()
    second_attempting_lock = asyncio.Event()
    second_pid = None
    original_group = GuestRepository.group

    async def instrumented_group(repository, group_id, *, lock=False):
        nonlocal second_pid
        task_name = asyncio.current_task().get_name()
        if lock and task_name == "second-patch":
            second_pid = await repository.session.scalar(text("SELECT pg_backend_pid()"))
            second_attempting_lock.set()
        result = await original_group(repository, group_id, lock=lock)
        if lock and task_name == "first-patch":
            first_holds_lock.set()
            await release_first.wait()
        return result

    monkeypatch.setattr(GuestRepository, "group", instrumented_group)

    async def patch(uid):
        return await client.patch(
            path, headers=bearer(uid),
            json={"expected_revision": 1, "data": graphs[uid]},
        )

    second_uid = "editor" if first_uid == "host" else "host"
    first = asyncio.create_task(patch(first_uid), name="first-patch")
    second = None
    try:
        await asyncio.wait_for(first_holds_lock.wait(), timeout=5)
        second = asyncio.create_task(patch(second_uid), name="second-patch")
        await asyncio.wait_for(second_attempting_lock.wait(), timeout=5)

        async def observe_database_lock():
            # Prove a real PostgreSQL lock wait, not merely sequential coroutines.
            async with sessions() as session:
                while True:
                    waiting = await session.scalar(text(
                        "SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = :pid"
                    ), {"pid": second_pid})
                    if waiting:
                        return
                    await session.execute(text("SELECT pg_stat_clear_snapshot()"))
                    await asyncio.sleep(0.01)

        await asyncio.wait_for(observe_database_lock(), timeout=5)
        assert not first.done()
        assert not second.done()
        release_first.set()
        winner, loser = await asyncio.wait_for(asyncio.gather(first, second), timeout=10)
    finally:
        release_first.set()
        for task in (first, second):
            if task is not None and not task.done():
                task.cancel()
        await asyncio.gather(
            *(task for task in (first, second) if task is not None),
            return_exceptions=True,
        )
    assert winner.status_code == 200, winner.text
    assert loser.status_code == 409, loser.text
    assert winner.json() == {
        **entry, "data": graphs[first_uid], "revision": 2, "updated_by_uid": first_uid,
    }
    reloaded = await client.get(path, headers=bearer(second_uid))
    exported = await client.get(path + "/export", headers=bearer(second_uid))
    assert reloaded.status_code == exported.status_code == 200
    assert reloaded.json() == exported.json() == winner.json()
    history = await client.get(path + "/history", headers=bearer(second_uid))
    assert history.status_code == 200
    assert history.json() == [
        {"revision": 1, "title": entry["title"], "data": interact_graph(), "edited_by_uid": first_uid},
        {"revision": 2, "title": entry["title"], "data": graphs[first_uid], "edited_by_uid": first_uid},
    ]
    async with sessions() as session:
        assert await session.scalar(select(func.count(GuestGroupEntry.id))) == 1
        assert await session.scalar(select(func.count(GuestGroupEntryRevision.id))) == 1

    # Reconciliation alone never authorises a blind retry with the old revision.
    replay = await patch(second_uid)
    assert replay.status_code == 409
    resolved = await client.patch(
        path, headers=bearer(second_uid),
        json={"expected_revision": 2, "data": graphs[second_uid]},
    )
    assert resolved.status_code == 200, resolved.text
    final_history = await client.get(path + "/history", headers=bearer("host"))
    assert [item["revision"] for item in final_history.json()] == [1, 2, 3]
    assert [item["data"] for item in final_history.json()] == [
        interact_graph(), graphs[first_uid], graphs[second_uid],
    ]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "role,own,status",
    [
        ("admin", True, 200), ("admin", False, 200),
        ("editor", True, 200), ("editor", False, 200),
        ("contributor", True, 200), ("contributor", False, 403),
        ("viewer", True, 403), ("viewer", False, 403),
        ("nonmember", False, 404),
    ],
)
async def test_postgres_interact_patch_permissions(postgres_client, monkeypatch, role, own, status):
    await interact_tests.test_interact_patch_role_and_authorship_matrix(
        postgres_client, monkeypatch, role, own, status
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "change,status",
    [
        ("revoked", 403), ("removed", 404), ("archived", 404),
        ("deleted_group", 404), ("deleted_entry", 404),
    ],
)
async def test_postgres_interact_lost_access(postgres_client, monkeypatch, change, status):
    await interact_tests.test_interact_open_then_lost_access_cannot_save(
        postgres_client, monkeypatch, change, status
    )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "provider,verified", [("anonymous", False), ("password", False), ("password", True)]
)
async def test_postgres_interact_registration(postgres_client, monkeypatch, provider, verified):
    await interact_tests.test_interact_patch_registration_rechecked_on_existing_uid(
        postgres_client, monkeypatch, provider, verified
    )


@pytest.mark.asyncio
async def test_postgres_interact_organisation_independence(postgres_client, monkeypatch):
    await interact_tests.test_interact_patch_organisation_admin_has_no_group_authority(
        postgres_client, monkeypatch
    )


@pytest.mark.asyncio
async def test_postgres_interact_graph_and_original_independence(postgres_client, monkeypatch):
    await interact_tests.test_interact_patch_persists_graph_history_export_and_independent_originals(
        postgres_client, monkeypatch
    )
