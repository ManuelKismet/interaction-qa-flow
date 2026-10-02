import argparse
import asyncio
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.models import FirebaseUidMapping, Organisation, User, UserRole


async def seed(firebase_uid: str) -> None:
    settings = get_settings()
    if settings.app_env != "development" or settings.firebase_project_id != "intqaflow-dev":
        raise SystemExit("Synthetic memberships are restricted to intqaflow-dev.")

    engine = create_async_engine(settings.database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    organisation_id = uuid.uuid5(uuid.NAMESPACE_URL, "intqaflow-dev:synthetic-tenant")
    user_id = uuid.uuid5(uuid.NAMESPACE_URL, f"intqaflow-dev:synthetic-user:{firebase_uid}")

    async with session_factory() as session:
        organisation = await session.get(Organisation, organisation_id)
        if organisation is None:
            organisation = Organisation(
                id=organisation_id,
                name="Synthetic Development Tenant",
                slug="synthetic-development",
            )
            session.add(organisation)

        user = await session.get(User, user_id)
        if user is None:
            user = User(
                id=user_id,
                organisation_id=organisation_id,
                email="synthetic-admin@invalid.example",
                display_name="Synthetic Development Admin",
                role=UserRole.ADMIN,
                status="active",
            )
            session.add(user)
        elif user.organisation_id != organisation_id:
            raise SystemExit("Synthetic user ID is already assigned to another tenant.")
        else:
            user.email = "synthetic-admin@invalid.example"
            user.display_name = "Synthetic Development Admin"
            user.role = UserRole.ADMIN
            user.status = "active"

        uid_mapping = await session.get(FirebaseUidMapping, firebase_uid)
        if uid_mapping is not None and uid_mapping.user_id != user_id:
            raise SystemExit("Firebase UID is already mapped to another user.")
        user_mapping = await session.scalar(
            select(FirebaseUidMapping).where(
                FirebaseUidMapping.user_id == user_id
            )
        )
        if user_mapping is not None and user_mapping.firebase_uid != firebase_uid:
            raise SystemExit("Synthetic user already has a different Firebase UID.")
        if uid_mapping is None:
            session.add(
                FirebaseUidMapping(firebase_uid=firebase_uid, user_id=user_id)
            )
        await session.commit()
        print(f"Synthetic membership ready for Firebase UID {firebase_uid}.")

    await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create the repeatable synthetic IntQAFlow development tenant."
    )
    parser.add_argument("--firebase-uid", required=True)
    parser.add_argument("--confirm-development", action="store_true")
    args = parser.parse_args()
    if not args.confirm_development:
        parser.error("--confirm-development is required")
    if not args.firebase_uid.strip() or len(args.firebase_uid) > 128:
        parser.error("--firebase-uid must be a non-empty Firebase UID")
    asyncio.run(seed(args.firebase_uid))


if __name__ == "__main__":
    main()
