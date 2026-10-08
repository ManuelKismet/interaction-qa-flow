from collections.abc import AsyncIterator
from uuid import UUID

import pytest_asyncio
from fastapi import Request
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_session
from app.api.dependencies import (
    AuthenticatedIdentity,
    enforce_tenant_scope,
    get_development_identity,
)
from app.main import app
from app.models import Base


@pytest_asyncio.fixture
async def app_client() -> AsyncIterator[
    tuple[AsyncClient, async_sessionmaker[AsyncSession]]
]:
    test_engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    session_factory = async_sessionmaker(test_engine, expire_on_commit=False)

    async with test_engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def override_session() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    async def override_identity(request: Request) -> AuthenticatedIdentity:
        body = await request.json() if request.headers.get("content-type", "").startswith("application/json") else {}
        if not isinstance(body, dict):
            body = {}
        organisation_id = (
            request.headers.get("X-Organisation-ID")
            or request.query_params.get("organisation_id")
            or body.get("organisation_id")
            or str(UUID(int=0))
        )
        user_id = (
            request.headers.get("X-User-ID")
            or request.query_params.get("user_id")
            or body.get("user_id")
            or body.get("author_id")
            or body.get("created_by")
            or str(UUID(int=0))
        )
        return AuthenticatedIdentity(
            organisation_id=UUID(str(organisation_id)),
            user_id=UUID(str(user_id)),
            firebase_uid="test-uid",
            email="test@example.invalid",
            display_name="Test user",
            role="employee",
        )

    async def override_scope(_: Request) -> None:
        return None

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_development_identity] = override_identity
    app.dependency_overrides[enforce_tenant_scope] = override_scope
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client, session_factory

    app.dependency_overrides.clear()
    await test_engine.dispose()