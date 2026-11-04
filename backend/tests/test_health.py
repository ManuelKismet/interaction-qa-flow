import pytest
from sqlalchemy.exc import OperationalError

from app.api.dependencies import get_session
from app.main import app


@pytest.mark.asyncio
async def test_health_returns_ok(app_client) -> None:
    client, _ = app_client

    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_readiness_checks_database_schema(app_client) -> None:
    client, _ = app_client

    response = await client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


@pytest.mark.asyncio
async def test_readiness_failure_is_sanitized_and_liveness_remains_available(
    app_client,
) -> None:
    client, _ = app_client
    session_override = app.dependency_overrides[get_session]

    class UnavailableSession:
        async def execute(self, _statement):
            raise OperationalError(
                "SELECT id FROM organisations LIMIT 0",
                {},
                OSError("private connection detail"),
            )

    async def unavailable_session():
        yield UnavailableSession()

    app.dependency_overrides[get_session] = unavailable_session
    try:
        readiness = await client.get("/ready")
        health = await client.get("/health")
    finally:
        app.dependency_overrides[get_session] = session_override

    assert readiness.status_code == 503
    assert readiness.json() == {"status": "not_ready"}
    assert "private connection detail" not in readiness.text
    assert health.status_code == 200
    assert health.json()["status"] == "ok"