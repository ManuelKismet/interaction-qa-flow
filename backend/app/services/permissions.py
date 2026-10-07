from uuid import UUID

from sqlalchemy import and_, or_, select

from app.core.exceptions import NotFoundError, PermissionDeniedError
from app.models.organisation import Organisation
from app.models.organisation_owner import OrganisationOwner
from app.models.organisation_permission import OrganisationPermissionGrant
from app.models.question import Question, QuestionVisibility
from app.models.user import User, UserRole
from app.repositories.governance import GovernanceRepository
from app.repositories.user import UserRepository


class PermissionService:
    def __init__(self, users: UserRepository) -> None:
        self.users = users
        self.session = users.session

    async def actor(self, user_id: UUID, organisation_id: UUID) -> User:
        await self.lock_organisation(organisation_id)
        actor = await self.session.scalar(
            select(User)
            .where(
                User.id == user_id,
                User.organisation_id == organisation_id,
                User.status == "active",
            )
            .with_for_update()
        )
        if not actor:
            raise NotFoundError("User not found in this organisation")
        return actor

    async def lock_organisation(self, organisation_id: UUID) -> None:
        if await self.session.scalar(
            select(Organisation.id)
            .where(Organisation.id == organisation_id)
            .with_for_update()
        ) is None:
            raise NotFoundError("Organisation not found")

    async def require_question_owner_or_admin(
        self, actor: User, question: Question
    ) -> None:
        if actor.id != question.author_id and not await self.is_organisation_admin(actor):
            raise PermissionDeniedError("Only the question author or an admin can do this")

    @staticmethod
    def require_owner(actor: User, owner_id: UUID) -> None:
        if actor.id != owner_id:
            raise PermissionDeniedError("You can only change your own content")

    async def is_owner(self, actor: User) -> bool:
        return bool(
            await self.session.scalar(
                select(OrganisationOwner.id)
                .where(
                    OrganisationOwner.organisation_id == actor.organisation_id,
                    OrganisationOwner.user_id == actor.id,
                    User.status == "active",
                )
                .join(User, User.id == OrganisationOwner.user_id)
            )
        )

    async def is_organisation_admin(self, actor: User) -> bool:
        if actor.status != "active":
            return False
        await self.lock_organisation(actor.organisation_id)
        if await self.is_owner(actor):
            return True
        return bool(
            await self.session.scalar(
                select(OrganisationPermissionGrant.id).where(
                    OrganisationPermissionGrant.organisation_id
                    == actor.organisation_id,
                    OrganisationPermissionGrant.user_id == actor.id,
                    OrganisationPermissionGrant.permission == "legacy_admin",
                    OrganisationPermissionGrant.revoked_at.is_(None),
                )
            )
        )

    async def require_admin(self, actor: User) -> None:
        if not await self.is_organisation_admin(actor):
            raise PermissionDeniedError("Administrator permission is required")

    async def has_permission(
        self,
        actor: User,
        permission: str,
        *,
        department_id: UUID | None = None,
        team_id: UUID | None = None,
    ) -> bool:
        if actor.status != "active":
            return False
        await self.lock_organisation(actor.organisation_id)
        if await self.is_owner(actor):
            return True
        grants = list(
            await self.session.scalars(
                select(OrganisationPermissionGrant).where(
                    OrganisationPermissionGrant.organisation_id
                    == actor.organisation_id,
                    OrganisationPermissionGrant.user_id == actor.id,
                    OrganisationPermissionGrant.revoked_at.is_(None),
                    OrganisationPermissionGrant.permission.in_(
                        [permission, "legacy_admin"]
                    ),
                )
            )
        )
        for grant in grants:
            if grant.permission == "legacy_admin":
                return True
            if grant.scope_type == "organisation":
                return True
            if (
                grant.scope_type == "department"
                and department_id is not None
                and grant.scope_id == department_id
            ):
                return True
            if (
                grant.scope_type == "team"
                and team_id is not None
                and grant.scope_id == team_id
            ):
                return True
        return False

    async def require_permission(
        self,
        actor: User,
        permission: str,
        *,
        department_id: UUID | None = None,
        team_id: UUID | None = None,
    ) -> None:
        if not await self.has_permission(
            actor,
            permission,
            department_id=department_id,
            team_id=team_id,
        ):
            raise PermissionDeniedError(
                "You do not have the required scoped organisation permission"
            )

    async def has_any_permission(self, actor: User, permission: str) -> bool:
        if actor.status != "active":
            return False
        await self.lock_organisation(actor.organisation_id)
        if await self.is_owner(actor):
            return True
        return bool(
            await self.session.scalar(
                select(OrganisationPermissionGrant.id).where(
                    OrganisationPermissionGrant.organisation_id
                    == actor.organisation_id,
                    OrganisationPermissionGrant.user_id == actor.id,
                    OrganisationPermissionGrant.revoked_at.is_(None),
                    OrganisationPermissionGrant.permission.in_(
                        [permission, "legacy_admin"]
                    ),
                )
            )
        )

    @staticmethod
    def question_visibility_clause(actor: User, question=Question):
        visibility = or_(
            question.visibility == QuestionVisibility.ORGANISATION,
            and_(
                question.visibility == QuestionVisibility.PRIVATE,
                question.author_id == actor.id,
            ),
        )
        if actor.department_id is not None:
            visibility = or_(
                visibility,
                and_(
                    question.visibility == QuestionVisibility.DEPARTMENT,
                    question.department_id == actor.department_id,
                ),
            )
        return visibility

    @staticmethod
    def can_view_question(actor: User, question: Question) -> bool:
        if question.visibility.value == "organisation":
            return True
        if question.visibility.value == "private" and question.author_id == actor.id:
            return True
        if (
            question.visibility.value == "department"
            and actor.department_id is not None
            and question.department_id is not None
            and actor.department_id == question.department_id
        ):
            return True
        return False

    @staticmethod
    def require_question_visibility(actor: User, question: Question) -> None:
        if PermissionService.can_view_question(actor, question):
            return
        raise PermissionDeniedError("You do not have permission to view this question")

    async def require_answer_manager(
        self,
        actor: User,
        question: Question,
        governance: GovernanceRepository,
        *,
        permission: str = "answer_approval",
    ) -> None:
        department_id = question.department_id
        if department_id is None and question.team_id is not None:
            department_id = await governance.team_department_id(
                question.team_id, actor.organisation_id
            )
        if await self.has_permission(
            actor,
            permission,
            department_id=department_id,
            team_id=question.team_id,
        ):
            return
        if (
            actor.role == UserRole.ANSWER_OWNER
            and department_id is not None
            and await governance.is_department_owner(
                actor.organisation_id,
                department_id,
                actor.id,
            )
        ):
            return
        raise PermissionDeniedError(
            "You do not have permission to govern answers for this department"
        )