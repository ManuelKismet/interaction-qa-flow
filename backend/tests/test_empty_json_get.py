import asyncio
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from starlette.requests import Request
from app.api.dependencies import enforce_tenant_scope

def check(body):
    async def receive():
        return {"type": "http.request", "body": body, "more_body": False}
    request = Request({"type": "http", "method": "GET", "path": "/api/v1/auth/me", "query_string": b"", "headers": [(b"content-type", b"application/json")]}, receive)
    identity = SimpleNamespace(organisation_id=uuid4(), user_id=uuid4())
    asyncio.run(enforce_tenant_scope(request, identity))

def test_empty_json_get_is_allowed():
    check(b"")

def test_nonempty_malformed_json_still_rejected():
    with pytest.raises(HTTPException) as caught:
        check(b"not-json")
    assert caught.value.status_code == 400

def test_nonempty_cross_tenant_json_still_rejected():
    with pytest.raises(HTTPException) as caught:
        check(b'{"organisation_id":"other-tenant"}')
    assert caught.value.status_code == 403
