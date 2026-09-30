from uuid import UUID

from app.core.exceptions import NotFoundError, PermissionDeniedError
from app.models.question import Question
from app.models.user import User, UserRole
from app.repositories.governance import GovernanceRepository
from app.repositories.user import UserRepository


class PermissionService:
    def __init__(self, users: UserRepository) -> None:
        self.users = users

    async def actor(self, user_id: UUID, organisation_id: UUID) -> User:
        actor = await self.users.get_for_organisation(user_id, organisation_id)
        if not actor:
            raise NotFoundError("User not found in this organisation")
        return actor

    @staticmethod
    def require_question_owner_or_admin(actor: User, question: Question) -> None:
        if actor.id != question.author_id and actor.role != UserRole.ADMIN:
            raise PermissionDeniedError("Only the question author or an admin can do this")

    @staticmethod
    def require_owner(actor: User, owner_id: UUID) -> None:
        if actor.id != owner_id:
            raise PermissionDeniedError("You can only change your own content")

    @staticmethod
    def require_admin(actor: User) -> None:
        if actor.role != UserRole.ADMIN:
            raise PermissionDeniedError("Administrator permission is required")

    @staticmethod
    def require_question_visibility(actor: User, question: Question) -> None:
        if question.visibility.value == "organisation":
            return
        if question.visibility.value == "private" and question.author_id == actor.id:
            return
        if (
            question.visibility.value == "department"
            and actor.department_id is not None
            and actor.department_id == question.department_id
        ):
            return
        raise PermissionDeniedError("You do not have permission to view this answer")

    @staticmethod
    async def require_answer_manager(
        actor: User,
        question: Question,
        governance: GovernanceRepository,
    ) -> None:
        if actor.role == UserRole.ADMIN:
            return
        department_id = question.department_id
        if department_id is None and question.team_id is not None:
            department_id = await governance.team_department_id(
                question.team_id, actor.organisation_id
            )
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