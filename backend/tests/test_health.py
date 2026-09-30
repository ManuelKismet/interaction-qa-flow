import pytest


@pytest.mark.asyncio
async def test_health_returns_ok(app_client) -> None:
    client, _ = app_client

    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"