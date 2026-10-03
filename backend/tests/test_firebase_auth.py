from uuid import uuid4

import pytest
from firebase_admin import auth
from sqlalchemy import select

from app.api import dependencies
from app.api.dependencies import enforce_tenant_scope, get_development_identity
from app.core.config import Settings, get_settings
from app.main import app
from app.models import FirebaseUidMapping, Organisation, User, UserRole

PROJECT_ID = "intqaflow-dev"
APP_ID = "1:398672910103:web:e968506023d8eab9290952"
FIREBASE_UID = "synthetic-user-uid"


def bearer_header() -> str:
    return "".join(("bear", "er ", "synthetic-test-id-token"))


def use_real_identity_dependencies() -> None:
    app.dependency_overrides.pop(get_development_identity, None)
    app.dependency_overrides.pop(enforce_tenant_scope, None)


async def seed_membership(session_factory, *, status: str = "active") -> tuple:
    organisation_id = uuid4()
    user_id = uuid4()
    async with session_factory() as session:
        session.add(
            Organisation(
                id=organisation_id,
                name="Test organisation",
                slug=f"test-{organisation_id}",
            )
        )
        session.add(
            User(
                id=user_id,
                organisation_id=organisation_id,
                email="synthetic@example.invalid",
                display_name="Synthetic user",
                role=UserRole.ADMIN,
                status=status,
            )
        )
        session.add(
            FirebaseUidMapping(firebase_uid=FIREBASE_UID, user_id=user_id)
        )
        await session.commit()
    return organisation_id, user_id


def valid_claims() -> dict[str, str]:
    return {
        "aud": PROJECT_ID,
        "iss": f"https://securetoken.google.com/{PROJECT_ID}",
        "sub": FIREBASE_UID,
    }


@pytest.mark.asyncio
async def test_valid_uid_membership_ignores_forged_development_headers(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    organisation_id, user_id = await seed_membership(session_factory)
    use_real_identity_dependencies()
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: valid_claims())

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": bearer_header()},
    )
    assert response.status_code == 200
    assert response.json()["user_id"] == str(user_id)
    assert response.json()["organisation_id"] == str(organisation_id)
    assert response.json()["role"] == "admin"

    forged = await client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization": bearer_header(),
            "X-User-ID": str(uuid4()),
            "X-Organisation-ID": str(uuid4()),
            "X-User-Role": "admin",
        },
    )
    assert forged.status_code == 400


@pytest.mark.asyncio
async def test_missing_and_invalid_identity_tokens_fail_closed(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    use_real_identity_dependencies()

    missing = await client.get("/api/v1/auth/me")
    assert missing.status_code == 401
    missing_account_state = await client.get("/api/v1/account/state")
    assert missing_account_state.status_code == 401
    unauthenticated_api = await client.get("/api/v1/teams")
    assert unauthenticated_api.status_code == 401
    bootstrap = await client.post(
        "/api/v1/organisations",
        json={"name": "Untrusted", "slug": "untrusted"},
    )
    assert bootstrap.status_code == 404

    monkeypatch.setattr(
        dependencies,
        "verify_id_token",
        lambda *_: (_ for _ in ()).throw(ValueError("invalid token")),
    )
    malformed = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": bearer_header()},
    )
    assert malformed.status_code == 401
    malformed_account_state = await client.get(
        "/api/v1/account/state",
        headers={"Authorization": bearer_header()},
    )
    assert malformed_account_state.status_code == 401

    monkeypatch.setattr(
        dependencies,
        "verify_id_token",
        lambda *_: (_ for _ in ()).throw(auth.ExpiredIdTokenError("expired", None)),
    )
    expired = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": bearer_header()},
    )
    assert expired.status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "claims",
    [
        {"aud": "another-project", "iss": "https://securetoken.google.com/another-project", "sub": FIREBASE_UID},
        {"aud": PROJECT_ID, "iss": "https://wrong-issuer.example", "sub": FIREBASE_UID},
        {"aud": PROJECT_ID, "iss": f"https://securetoken.google.com/{PROJECT_ID}", "sub": ""},
    ],
)
async def test_wrong_project_issuer_and_empty_uid_are_rejected(
    app_client, monkeypatch, claims
) -> None:
    client, _ = app_client
    use_real_identity_dependencies()
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: claims)

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": bearer_header()},
    )

    assert response.status_code == 401


@pytest.mark.asyncio
async def test_unmapped_and_inactive_firebase_users_are_rejected(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    organisation_id = uuid4()
    async with session_factory() as session:
        session.add(
            Organisation(
                id=organisation_id,
                name="Test organisation",
                slug=f"test-{organisation_id}",
            )
        )
        await session.commit()
    use_real_identity_dependencies()
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: valid_claims())
    headers = {"Authorization": bearer_header()}

    unmapped = await client.get("/api/v1/auth/me", headers=headers)
    assert unmapped.status_code == 401

    await seed_membership(session_factory, status="inactive")
    inactive = await client.get("/api/v1/auth/me", headers=headers)
    assert inactive.status_code == 401


@pytest.mark.asyncio
async def test_account_state_distinguishes_guest_unmapped_inactive_and_active(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    use_real_identity_dependencies()
    monkeypatch.setattr(
        dependencies,
        "verify_id_token",
        lambda *_: {
            **valid_claims(),
            "firebase": {"sign_in_provider": "password"},
        },
    )
    headers = {"Authorization": bearer_header()}

    unmapped = await client.get("/api/v1/account/state", headers=headers)
    assert unmapped.status_code == 200
    assert unmapped.json() == {"status": "no_membership"}
    forged_identity = await client.get(
        "/api/v1/account/state",
        headers={
            **headers,
            "X-User-ID": str(uuid4()),
            "X-Organisation-ID": str(uuid4()),
            "X-User-Role": "admin",
        },
    )
    assert forged_identity.status_code == 400

    await seed_membership(session_factory, status="inactive")
    inactive = await client.get("/api/v1/account/state", headers=headers)
    assert inactive.status_code == 200
    assert inactive.json() == {"status": "inactive"}

    async with session_factory() as session:
        user = await session.scalar(
            select(User).where(User.email == "synthetic@example.invalid")
        )
        user.status = "active"
        await session.commit()

    active = await client.get("/api/v1/account/state", headers=headers)
    assert active.status_code == 200
    assert active.json() == {"status": "active"}

    monkeypatch.setattr(
        dependencies,
        "verify_id_token",
        lambda *_: {
            **valid_claims(),
            "firebase": {"sign_in_provider": "anonymous"},
        },
    )
    guest = await client.get("/api/v1/account/state", headers=headers)
    assert guest.status_code == 200
    assert guest.json() == {"status": "shared_guest"}


@pytest.mark.asyncio
async def test_app_check_observation_allows_missing_but_rejects_invalid_tokens(
    app_client, monkeypatch
) -> None:
    client, _ = app_client
    await seed_membership(app_client[1])
    use_real_identity_dependencies()
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: valid_claims())
    monkeypatch.setattr(
        dependencies,
        "verify_app_check_token",
        lambda *_: {"app_id": "wrong-app"},
    )
    headers = {"Authorization": bearer_header()}

    missing = await client.get("/api/v1/auth/me", headers=headers)
    assert missing.status_code == 200

    invalid = await client.get(
        "/api/v1/auth/me",
        headers={**headers, "X-Firebase-AppCheck": "invalid"},
    )
    assert invalid.status_code == 401

    monkeypatch.setattr(
        dependencies,
        "verify_app_check_token",
        lambda *_: (_ for _ in ()).throw(ValueError("invalid token")),
    )
    malformed = await client.get(
        "/api/v1/auth/me",
        headers={**headers, "X-Firebase-AppCheck": "malformed"},
    )
    assert malformed.status_code == 401


@pytest.mark.asyncio
async def test_app_check_enforcement_rejects_missing_and_wrong_app(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    await seed_membership(session_factory)
    use_real_identity_dependencies()
    app.dependency_overrides[get_settings] = lambda: Settings(app_check_mode="enforce")
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: valid_claims())
    monkeypatch.setattr(
        dependencies,
        "verify_app_check_token",
        lambda *_: {"app_id": "wrong-app"},
    )
    headers = {"Authorization": bearer_header()}

    missing = await client.get("/api/v1/auth/me", headers=headers)
    assert missing.status_code == 401
    missing_account_state = await client.get(
        "/api/v1/account/state",
        headers=headers,
    )
    assert missing_account_state.status_code == 401

    wrong_app = await client.get(
        "/api/v1/auth/me",
        headers={**headers, "X-Firebase-AppCheck": "validly-signed-wrong-app"},
    )
    assert wrong_app.status_code == 401
    wrong_app_state = await client.get(
        "/api/v1/account/state",
        headers={**headers, "X-Firebase-AppCheck": "validly-signed-wrong-app"},
    )
    assert wrong_app_state.status_code == 401

    monkeypatch.setattr(
        dependencies,
        "verify_app_check_token",
        lambda *_: {"app_id": APP_ID},
    )
    valid = await client.get(
        "/api/v1/auth/me",
        headers={**headers, "X-Firebase-AppCheck": "validly-signed"},
    )
    assert valid.status_code == 200


@pytest.mark.asyncio
async def test_cross_tenant_selection_and_role_restrictions_are_rejected(
    app_client, monkeypatch
) -> None:
    client, session_factory = app_client
    organisation_id, _ = await seed_membership(session_factory)
    use_real_identity_dependencies()
    monkeypatch.setattr(dependencies, "verify_id_token", lambda *_: valid_claims())
    headers = {"Authorization": bearer_header()}

    wrong_tenant = await client.post(
        "/api/v1/questions",
        headers=headers,
        json={
            "organisation_id": str(uuid4()),
            "title": "Forged tenant",
        },
    )
    assert wrong_tenant.status_code == 403
    forged_actor = await client.post(
        "/api/v1/questions",
        headers=headers,
        json={"author_id": str(uuid4()), "title": "Forged author"},
    )
    assert forged_actor.status_code == 403

    async with session_factory() as session:
        user = await session.scalar(
            select(User).where(User.email == "synthetic@example.invalid")
        )
        user.role = UserRole.EMPLOYEE
        await session.commit()

    admin_action = await client.post(
        "/api/v1/departments",
        headers=headers,
        json={"name": "Restricted department"},
    )
    assert admin_action.status_code == 403
