from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_event import AuditAction, AuditEvent
from app.models.department import Department
from app.models.firebase_uid_mapping import FirebaseUidMapping
from app.models.organisation import Organisation
from app.models.user import User, UserRole
from app.schemas.organisation_member import (
    OrganisationMemberCreate,
    OrganisationMemberUpdate,
)


class OrganisationMemberService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def _lock_organisation(self, organisation_id: UUID) -> None:
        organisation = await self.session.scalar(
            select(Organisation)
            .where(Organisation.id == organisation_id)
            .with_for_update()
        )
        if organisation is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Organisation not found",
            )

    async def _require_not_last_admin(
        self,
        organisation_id: UUID,
        member: User,
        new_role: UserRole,
    ) -> None:
        if member.role != UserRole.ADMIN or new_role == UserRole.ADMIN:
            return
        active_admins = await self.session.scalar(
            select(func.count())
            .select_from(User)
            .where(
                User.organisation_id == organisation_id,
                User.status == "active",
                User.role == UserRole.ADMIN,
            )
        )
        if (active_admins or 0) <= 1:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="The last active organisation admin cannot be demoted",
            )

    async def list_members(
        self, organisation_id: UUID
    ) -> list[dict[str, object]]:
        result = await self.session.execute(
            select(User, Department.name)
            .outerjoin(
                Department,
                and_(
                    Department.id == User.department_id,
                    Department.organisation_id == User.organisation_id,
                ),
            )
            .where(
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .order_by(User.display_name, User.id)
        )
        return [
            {
                "id": user.id,
                "email": user.email,
                "display_name": user.display_name,
                "role": user.role,
                "status": user.status,
                "department_id": user.department_id,
                "department_name": department_name,
            }
            for user, department_name in result.all()
        ]

    async def update_member(
        self,
        *,
        organisation_id: UUID,
        actor_id: UUID,
        member_id: UUID,
        update: OrganisationMemberUpdate,
    ) -> dict[str, object]:
        fields_set = update.model_fields_set
        if not fields_set:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="At least one membership field must be provided",
            )

        await self._lock_organisation(organisation_id)
        member = await self.session.scalar(
            select(User)
            .where(
                User.id == member_id,
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .with_for_update()
        )
        if member is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Active organisation member not found",
            )

        if "role" in fields_set:
            if update.role is None:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Role cannot be null",
                )
            await self._require_not_last_admin(
                organisation_id,
                member,
                update.role,
            )
            if member.role != update.role:
                self.session.add(
                    AuditEvent(
                        organisation_id=organisation_id,
                        actor_id=actor_id,
                        action=AuditAction.ORGANISATION_MEMBER_ROLE_CHANGED.value,
                        entity_type="user",
                        entity_id=member.id,
                        event_metadata={
                            "old_role": member.role.value,
                            "new_role": update.role.value,
                        },
                    )
                )
                member.role = update.role

        if "department_id" in fields_set:
            new_department_id = update.department_id
            if new_department_id is not None:
                department = await self.session.scalar(
                    select(Department).where(
                        Department.id == new_department_id,
                        Department.organisation_id == organisation_id,
                    )
                )
                if department is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Department not found in this organisation",
                    )
            if member.department_id != new_department_id:
                self.session.add(
                    AuditEvent(
                        organisation_id=organisation_id,
                        actor_id=actor_id,
                        action=AuditAction.USER_PRIMARY_DEPARTMENT_CHANGED.value,
                        entity_type="user",
                        entity_id=member.id,
                        event_metadata={
                            "old_department_id": (
                                str(member.department_id)
                                if member.department_id
                                else None
                            ),
                            "new_department_id": (
                                str(new_department_id)
                                if new_department_id
                                else None
                            ),
                        },
                    )
                )
                member.department_id = new_department_id

        try:
            await self.session.commit()
        except IntegrityError:
            await self.session.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Organisation membership could not be updated",
            ) from None
        return next(
            item
            for item in await self.list_members(organisation_id)
            if item["id"] == member_id
        )

    async def add_member(
        self,
        *,
        organisation_id: UUID,
        actor_id: UUID,
        firebase_uid: str,
        email: str,
        display_name: str | None,
        update: OrganisationMemberCreate,
    ) -> dict[str, object]:
        await self._lock_organisation(organisation_id)
        if update.department_id is not None:
            department = await self.session.scalar(
                select(Department).where(
                    Department.id == update.department_id,
                    Department.organisation_id == organisation_id,
                )
            )
            if department is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Department not found in this organisation",
                )

        mapping = await self.session.get(FirebaseUidMapping, firebase_uid)
        if mapping is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This registered account already has an organisation membership",
            )

        existing = await self.session.scalar(
            select(User)
            .where(
                User.organisation_id == organisation_id,
                func.lower(User.email) == email.lower(),
            )
            .with_for_update()
        )
        if existing is not None:
            if existing.status != "active":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="An inactive member already uses this email",
                )
            existing_mapping = await self.session.scalar(
                select(FirebaseUidMapping).where(
                    FirebaseUidMapping.user_id == existing.id
                )
            )
            if existing_mapping is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This email is already linked to an organisation account",
                )
            member = existing
            await self._require_not_last_admin(
                organisation_id,
                member,
                update.role,
            )
            if member.role != update.role:
                self.session.add(
                    AuditEvent(
                        organisation_id=organisation_id,
                        actor_id=actor_id,
                        action=AuditAction.ORGANISATION_MEMBER_ROLE_CHANGED.value,
                        entity_type="user",
                        entity_id=member.id,
                        event_metadata={
                            "old_role": member.role.value,
                            "new_role": update.role.value,
                        },
                    )
                )
                member.role = update.role
            if member.department_id != update.department_id:
                self.session.add(
                    AuditEvent(
                        organisation_id=organisation_id,
                        actor_id=actor_id,
                        action=AuditAction.USER_PRIMARY_DEPARTMENT_CHANGED.value,
                        entity_type="user",
                        entity_id=member.id,
                        event_metadata={
                            "old_department_id": (
                                str(member.department_id)
                                if member.department_id
                                else None
                            ),
                            "new_department_id": (
                                str(update.department_id)
                                if update.department_id
                                else None
                            ),
                        },
                    )
                )
                member.department_id = update.department_id
        else:
            member = User(
                organisation_id=organisation_id,
                department_id=update.department_id,
                email=email,
                display_name=display_name or email,
                role=update.role,
                status="active",
            )
            self.session.add(member)
            await self.session.flush()

        self.session.add(
            FirebaseUidMapping(firebase_uid=firebase_uid, user_id=member.id)
        )
        self.session.add(
            AuditEvent(
                organisation_id=organisation_id,
                actor_id=actor_id,
                action=AuditAction.ORGANISATION_MEMBER_ADDED.value,
                entity_type="user",
                entity_id=member.id,
                event_metadata={
                    "role": member.role.value,
                    "department_id": (
                        str(member.department_id) if member.department_id else None
                    ),
                },
            )
        )
        try:
            await self.session.commit()
        except IntegrityError:
            await self.session.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This account was concurrently added to an organisation",
            ) from None
        return next(
            item
            for item in await self.list_members(organisation_id)
            if item["id"] == member.id
        )
