import argparse
import asyncio
import re

from firebase_admin import auth
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.dependencies import firebase_app
from app.core.config import get_settings
from app.models import (
    AuditAction,
    AuditEvent,
    FirebaseUidMapping,
    Organisation,
    OrganisationOwner,
    User,
)
from app.models.user import UserRole


async def provision(
    *,
    name: str,
    slug: str,
    email: str,
    operator: str,
) -> None:
    settings = get_settings()
    account = auth.get_user_by_email(email, app=firebase_app(settings))
    if not account.email_verified or not account.email:
        raise SystemExit("Initial owner must have a verified Firebase email.")

    engine = create_async_engine(settings.database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with session_factory() as session:
            existing_organisation = await session.scalar(
                select(Organisation.id).where(Organisation.slug == slug)
            )
            if existing_organisation is not None:
                raise SystemExit("Organisation slug already exists.")
            if await session.get(FirebaseUidMapping, account.uid) is not None:
                raise SystemExit("Firebase account already has an organisation membership.")
            existing_user = await session.scalar(
                select(User.id).where(
                    func.lower(User.email) == account.email.lower()
                )
            )
            if existing_user is not None:
                raise SystemExit("A user record already uses the verified admin email.")

            organisation = Organisation(name=name, slug=slug)
            session.add(organisation)
            await session.flush()
            owner = User(
                organisation_id=organisation.id,
                email=account.email,
                display_name=account.display_name or account.email,
                role=UserRole.ADMIN,
                status="active",
            )
            session.add(owner)
            await session.flush()
            session.add(
                FirebaseUidMapping(firebase_uid=account.uid, user_id=owner.id)
            )
            session.add(
                OrganisationOwner(
                    organisation_id=organisation.id,
                    user_id=owner.id,
                    appointed_by=None,
                )
            )
            session.add(
                AuditEvent(
                    organisation_id=organisation.id,
                    actor_id=owner.id,
                    action=AuditAction.ORGANISATION_OWNER_PROVISIONED.value,
                    entity_type="user",
                    entity_id=owner.id,
                    event_metadata={
                        "operator": operator,
                        "method": "controlled_operator_cli",
                        "outcome": "owner_provisioned",
                    },
                )
            )
            try:
                await session.commit()
            except IntegrityError:
                await session.rollback()
                raise SystemExit(
                    "Provisioning conflicted with an existing organisation or membership."
                ) from None
            print(
                f"Organisation {organisation.id} and initial owner {owner.id} provisioned."
            )
    finally:
        await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Provision an organisation and its first verified owner."
    )
    parser.add_argument("--name", required=True)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--admin-email", required=True, help="Verified owner's email")
    parser.add_argument("--operator", required=True)
    parser.add_argument("--confirm-operator-provisioning", action="store_true")
    args = parser.parse_args()
    if not args.confirm_operator_provisioning:
        parser.error("--confirm-operator-provisioning is required")
    if not args.name.strip():
        parser.error("--name must be non-empty")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.slug):
        parser.error("--slug must contain lowercase letters, numbers, and hyphens")
    if not args.operator.strip():
        parser.error("--operator must be non-empty")
    asyncio.run(
        provision(
            name=args.name.strip(),
            slug=args.slug,
            email=args.admin_email.strip(),
            operator=args.operator.strip(),
        )
    )


if __name__ == "__main__":
    main()
