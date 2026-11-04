"""Real lock/CAS and tenant-constraint checks against a disposable schema."""

import asyncio
import os
from datetime import datetime, timezone
from uuid import uuid4
import pytest
import pytest_asyncio
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.api.dependencies import GuestIdentity
from app.core.exceptions import ConflictError
from app.models import Base, Department, FirebaseUidMapping
from app.models.suggestion_bank import BankActivity, BankSuggestion
from app.schemas.suggestion_bank import BankAction, BankCreate
from app.services.suggestion_bank import SuggestionBankService
from tests.test_answer_governance import seed_governance


@pytest_asyncio.fixture
async def pg_bank():
    url = os.environ.get("POSTGRES_TEST_DATABASE_URL")
    if not url:
        pytest.skip("POSTGRES_TEST_DATABASE_URL is not configured")
    schema = "bank_test_" + uuid4().hex
    bootstrap = create_async_engine(url)
    async with bootstrap.begin() as c:
        await c.execute(text('CREATE SCHEMA "' + schema + '"'))
    engine = create_async_engine(
        url,
        connect_args={
            "server_settings": {
                "search_path": schema + ",public",
                "statement_timeout": "15000",
            }
        },
    )
    try:
        async with engine.begin() as c:
            await c.run_sync(
                lambda connection: Base.metadata.create_all(
                    connection, checkfirst=False
                )
            )
        factory = async_sessionmaker(engine, expire_on_commit=False)
        ids = await seed_governance(factory)
        async with factory() as s:
            for who in ["employee", "admin"]:
                s.add(FirebaseUidMapping(firebase_uid=who, user_id=ids[who]))
            await s.commit()
        yield factory, ids
    finally:
        await engine.dispose()
        async with bootstrap.begin() as c:
            await c.execute(text('DROP SCHEMA "' + schema + '" CASCADE'))
        await bootstrap.dispose()


async def bank_service(session, who):
    return await SuggestionBankService(
        session,
        GuestIdentity(
            firebase_uid=who, sign_in_provider="password", email_verified=True
        ),
        "organisation",
    ).initialise()


@pytest.mark.asyncio
async def test_concurrent_acknowledgement_retry_and_conflicting_decisions(pg_bank):
    factory, ids = pg_bank
    payload = BankCreate(
        scope_type="organisation",
        scope_id=ids["organisation"],
        client_key="concurrent-create",
        title="Printer refill",
        problem="Empty tray",
        proposal="Refill it",
        benefit="Less waiting",
    )

    async def submit():
        async with factory() as session:
            return await (await bank_service(session, "employee")).create(payload)

    first, second = await asyncio.gather(submit(), submit())
    assert first["id"] == second["id"]
    async with factory() as session:
        assert (
            await session.scalar(select(func.count()).select_from(BankSuggestion)) == 1
        )
        assert await session.scalar(select(func.count()).select_from(BankActivity)) == 1

    async def decide(key):
        async with factory() as session:
            return await (await bank_service(session, "admin")).act(
                first["id"],
                BankAction(
                    action="respond",
                    client_key=key,
                    expected_revision=1,
                    text="Facilities will review this Friday.",
                ),
            )

    results = await asyncio.gather(decide("a"), decide("b"), return_exceptions=True)
    assert sum(isinstance(r, dict) for r in results) == 1
    assert sum(isinstance(r, ConflictError) for r in results) == 1
    async with factory() as session:
        assert await session.scalar(select(BankSuggestion.revision)) == 2
        assert await session.scalar(select(func.count()).select_from(BankActivity)) == 2


@pytest.mark.asyncio
async def test_database_rejects_cross_organisation_department_reference(pg_bank):
    factory, ids = pg_bank
    async with factory() as session:
        foreign = Department(
            organisation_id=ids["other_organisation"], name="Restricted"
        )
        session.add(foreign)
        await session.commit()
        department_id = foreign.id
    async with factory() as session:
        session.add(
            BankSuggestion(
                organisation_id=ids["organisation"],
                scope_type="department",
                department_id=department_id,
                kind="suggestion",
                title="Invalid tenant link",
                problem="x",
                proposal="x",
                benefit="",
                author_key="org:" + str(ids["employee"]),
                author_name="Employee",
                client_key="invalid-link",
                review_due_at=datetime.now(timezone.utc),
            )
        )
        with pytest.raises(IntegrityError):
            await session.commit()
