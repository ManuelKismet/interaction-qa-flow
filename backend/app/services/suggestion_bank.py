"""One trusted owner for Suggestion Bank policy, lifecycle and NIA context.

NIA is deterministic and permission-filtered. It never approves or widens access.
"""

from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher
from hashlib import sha256
import json
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy import and_, exists, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.exceptions import ConflictError, NotFoundError, PermissionDeniedError
from app.models import (
    Department,
    FirebaseUidMapping,
    Question,
    Team,
    TeamMembership,
    TeamStatus,
    User,
)
from app.models.answer import Answer, AnswerStatus
from app.models.guest import GuestGroupMembership
from app.models.suggestion_bank import BankActivity, BankFollower, BankSuggestion
from app.repositories.governance import GovernanceRepository
from app.repositories.user import UserRepository
from app.services.permissions import PermissionService
from app.services.guest import GuestService
from app.schemas.suggestion_bank import BankAction, BankCreate, BankScope

CLOSED = {"implemented", "not_proceeding"}
TRANSITIONS = {
    "submitted": {"under_review", "needs_information", "not_proceeding"},
    "under_review": {
        "needs_information",
        "planned",
        "in_progress",
        "implemented",
        "not_proceeding",
    },
    "needs_information": {"under_review", "not_proceeding"},
    "planned": {"under_review", "in_progress", "not_proceeding"},
    "in_progress": {"under_review", "implemented", "not_proceeding"},
    "implemented": {"under_review"},
    "not_proceeding": {"under_review"},
}


def utc(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class SuggestionBankService:
    def __init__(
        self,
        session: AsyncSession,
        identity,
        realm: str,
        *,
        rate_limit_action: str | None = "write"
    ):
        self.session, self.identity, self.realm = session, identity, realm
        self._rate_limit_action = rate_limit_action
        self.permissions = PermissionService(UserRepository(session))
        self.guest = GuestService(session)
        self.actor = None
        self.group = None
        self.member = None
        self.key = ""
        self.name = ""
        self._manager_cache = {}

    async def initialise(self):
        if self.realm == "organisation":
            user = await self.session.scalar(
                select(User)
                .join(FirebaseUidMapping, FirebaseUidMapping.user_id == User.id)
                .where(FirebaseUidMapping.firebase_uid == self.identity.firebase_uid)
            )
            if user is None or user.status != "active":
                raise PermissionDeniedError(
                    "An active organisation membership is required"
                )
            self.actor = await self.permissions.actor(user.id, user.organisation_id)
            self.key, self.name = "org:" + str(user.id), user.display_name
        elif self.realm == "group":
            if (
                self.identity.sign_in_provider == "anonymous"
                or not self.identity.email_verified
            ):
                raise PermissionDeniedError(
                    "Use a verified registered account for Group suggestions"
                )
            if self._rate_limit_action is not None:
                await self.guest._rate_limit(
                    self.identity.firebase_uid, self._rate_limit_action
                )
            self.key = "group:" + self.identity.firebase_uid
        else:
            raise PermissionDeniedError("Unknown workspace")
        return self

    def visible_clause(self):
        a = self.actor
        return and_(
            BankSuggestion.organisation_id == a.organisation_id,
            or_(
                BankSuggestion.scope_type == "organisation",
                (
                    and_(
                        BankSuggestion.scope_type == "department",
                        BankSuggestion.department_id == a.department_id,
                    )
                    if a.department_id
                    else False
                ),
                and_(
                    BankSuggestion.scope_type == "team",
                    select(TeamMembership.id)
                    .join(
                        Team,
                        and_(
                            Team.id == TeamMembership.team_id,
                            Team.organisation_id == TeamMembership.organisation_id,
                        ),
                    )
                    .where(
                        TeamMembership.organisation_id == a.organisation_id,
                        TeamMembership.user_id == a.id,
                        TeamMembership.team_id == BankSuggestion.team_id,
                        Team.status == TeamStatus.ACTIVE,
                    )
                    .exists(),
                ),
            ),
        )

    async def scope(self, data: BankScope):
        if data.scope_type == "group":
            if self.realm != "group":
                raise PermissionDeniedError("Switch to the Group workspace")
            self.group, self.member = await self.guest._group(
                data.scope_id, self.identity.firebase_uid
            )
            self.name = self.member.display_name
            return dict(
                organisation_id=None,
                group_id=data.scope_id,
                department_id=None,
                team_id=None,
                scope_type="group",
            )
        if self.realm != "organisation" or self.actor is None:
            raise PermissionDeniedError("Switch to the organisation workspace")
        a = self.actor
        result = dict(
            organisation_id=a.organisation_id,
            group_id=None,
            department_id=None,
            team_id=None,
            scope_type=data.scope_type,
        )
        if data.scope_type == "organisation":
            if data.scope_id != a.organisation_id:
                raise NotFoundError("Scope not found")
        elif data.scope_type == "department":
            department = await self.session.scalar(
                select(Department).where(
                    Department.id == data.scope_id,
                    Department.organisation_id == a.organisation_id,
                )
            )
            if department is None or a.department_id != department.id:
                raise NotFoundError("Scope not found")
            result["department_id"] = department.id
        elif data.scope_type == "team":
            team = await self.session.scalar(
                select(Team)
                .join(
                    TeamMembership,
                    and_(
                        TeamMembership.team_id == Team.id,
                        TeamMembership.organisation_id == Team.organisation_id,
                    ),
                )
                .where(
                    Team.id == data.scope_id,
                    Team.organisation_id == a.organisation_id,
                    Team.status == TeamStatus.ACTIVE,
                    TeamMembership.user_id == a.id,
                )
            )
            if team is None:
                raise NotFoundError("Scope not found")
            result["team_id"], result["department_id"] = team.id, team.department_id
        return result

    @staticmethod
    def scope_of(item):
        return BankScope(
            scope_type=item.scope_type,
            scope_id=item.group_id
            or item.team_id
            or item.department_id
            or item.organisation_id,
        )

    async def manager(self, item):
        scope = self.scope_of(item)
        key = (scope.scope_type, scope.scope_id)
        if key in self._manager_cache:
            return self._manager_cache[key]
        if self.realm == "group":
            await self.scope(scope)
            allowed = self.member.role == "admin"
        else:
            try:
                await self.permissions.require_answer_manager(
                    self.actor,
                    item,
                    GovernanceRepository(self.session),
                    permission="review",
                )
                allowed = True
            except PermissionDeniedError:
                allowed = False
        self._manager_cache[key] = allowed
        return allowed

    async def require_manager(self, item):
        if not await self.manager(item):
            raise PermissionDeniedError(
                "A reviewer with authority for this audience must do this"
            )

    def require_contributor(self):
        if self.realm == "group" and self.member.role not in {
            "admin",
            "editor",
            "contributor",
        }:
            raise PermissionDeniedError("Your Group role is read-only")

    async def scopes(self):
        if self.realm == "group":
            groups = await self.guest.list_groups(self.identity.firebase_uid)
            return [
                {"scope_type": "group", "scope_id": str(g["id"]), "label": g["name"]}
                for g in groups
            ]
        a = self.actor
        result = [
            {
                "scope_type": "organisation",
                "scope_id": str(a.organisation_id),
                "label": "Organisation",
            }
        ]
        if a.department_id:
            dept = await self.session.get(Department, a.department_id)
            if dept and dept.organisation_id == a.organisation_id:
                result.append(
                    {
                        "scope_type": "department",
                        "scope_id": str(dept.id),
                        "label": dept.name,
                    }
                )
        teams = await self.session.scalars(
            select(Team)
            .join(
                TeamMembership,
                and_(
                    TeamMembership.team_id == Team.id,
                    TeamMembership.organisation_id == Team.organisation_id,
                ),
            )
            .where(
                Team.organisation_id == a.organisation_id,
                TeamMembership.user_id == a.id,
                Team.status == TeamStatus.ACTIVE,
            )
            .order_by(Team.name)
            .limit(200)
        )
        result += [
            {"scope_type": "team", "scope_id": str(t.id), "label": t.name}
            for t in teams
        ]
        return result

    async def item(self, item_id, *, lock=False):
        stmt = select(BankSuggestion).where(BankSuggestion.id == item_id)
        if self.realm == "organisation":
            stmt = stmt.where(self.visible_clause())
        else:
            # A scope root is locked before its child, matching Group lifecycle.
            group_id = await self.session.scalar(
                select(BankSuggestion.group_id).where(
                    BankSuggestion.id == item_id, BankSuggestion.scope_type == "group"
                )
            )
            if group_id is None:
                raise NotFoundError("Suggestion not found")
            await self.scope(BankScope(scope_type="group", scope_id=group_id))
            stmt = stmt.where(BankSuggestion.group_id == group_id)
        item = await self.session.scalar(stmt.with_for_update() if lock else stmt)
        if item is None:
            raise NotFoundError("Suggestion not found")
        return item

    async def create(self, payload: BankCreate):
        audience = await self.scope(payload)
        self.require_contributor()
        existing = await self.session.scalar(
            select(BankSuggestion).where(
                BankSuggestion.author_key == self.key,
                BankSuggestion.client_key == payload.client_key,
            )
        )
        if existing:
            await self.item(existing.id)
            if any(getattr(existing, k) != v for k, v in audience.items()) or any(
                getattr(existing, k) != getattr(payload, k)
                for k in ("kind", "title", "problem", "proposal", "benefit")
            ):
                raise ConflictError(
                    "This submission key was already used for different content"
                )
            return await self.detail(existing.id)
        item = BankSuggestion(
            **audience,
            **payload.model_dump(
                include={
                    "kind",
                    "title",
                    "problem",
                    "proposal",
                    "benefit",
                    "client_key",
                }
            ),
            author_key=self.key,
            author_name=self.name,
            review_due_at=datetime.now(timezone.utc) + timedelta(days=7)
        )
        self.session.add(item)
        await self.session.flush()
        self.session.add(
            BankFollower(suggestion_id=item.id, actor_key=self.key, seen_revision=1)
        )
        self.session.add(
            BankActivity(
                suggestion_id=item.id,
                actor_key=self.key,
                actor_name=self.name,
                client_key=payload.client_key,
                action="submitted",
                text="Submitted for review",
                revision=1,
            )
        )
        await self.session.commit()
        return await self.detail(item.id)

    async def list(
        self,
        *,
        scope_type=None,
        scope_id=None,
        query="",
        queue="all",
        offset=0,
        limit=30
    ):
        stmt = select(BankSuggestion)
        if self.realm == "organisation":
            stmt = stmt.where(self.visible_clause())
            if scope_type and scope_id:
                audience = await self.scope(
                    BankScope(scope_type=scope_type, scope_id=scope_id)
                )
                stmt = stmt.where(
                    *(getattr(BankSuggestion, k) == v for k, v in audience.items())
                )
        else:
            if not scope_id:
                raise HTTPException(422, "Select a Group")
            audience = await self.scope(
                BankScope(scope_type="group", scope_id=scope_id)
            )
            stmt = stmt.where(BankSuggestion.group_id == audience["group_id"])
        if query:
            escaped = query.replace("!", "!!").replace("%", "!%").replace("_", "!_")
            stmt = stmt.where(
                or_(
                    BankSuggestion.title.ilike("%" + escaped + "%", escape="!"),
                    BankSuggestion.proposal.ilike("%" + escaped + "%", escape="!"),
                )
            )
        if queue == "practices":
            stmt = stmt.where(BankSuggestion.practice.is_not(None))
        elif queue == "unanswered":
            stmt = stmt.where(
                BankSuggestion.responded_at.is_(None),
                BankSuggestion.status.notin_(CLOSED),
            )
        elif queue == "overdue":
            stmt = stmt.where(
                BankSuggestion.review_due_at < datetime.now(timezone.utc),
                BankSuggestion.status.notin_(CLOSED),
            )
        elif queue in {"following", "updates"}:
            follow = select(BankFollower.id).where(
                BankFollower.suggestion_id == BankSuggestion.id,
                BankFollower.actor_key == self.key,
            )
            if queue == "updates":
                follow = follow.where(
                    BankFollower.seen_revision < BankSuggestion.revision
                )
            stmt = stmt.where(follow.exists())
        items = list(
            await self.session.scalars(
                stmt.order_by(BankSuggestion.created_at.desc(), BankSuggestion.id)
                .offset(offset)
                .limit(limit + 1)
            )
        )
        result = {
            "items": [await self.summary(i) for i in items[:limit]],
            "has_more": len(items) > limit,
            "offset": offset,
        }
        await self.session.commit()
        return result

    async def summary(self, item):
        follower = await self.session.scalar(
            select(BankFollower).where(
                BankFollower.suggestion_id == item.id,
                BankFollower.actor_key == self.key,
            )
        )
        return {
            "id": str(item.id),
            "scope_type": item.scope_type,
            "scope_id": str(self.scope_of(item).scope_id),
            "kind": item.kind,
            "title": item.title,
            "problem": item.problem,
            "proposal": item.proposal,
            "benefit": item.benefit,
            "author_name": item.author_name,
            "status": item.status,
            "revision": item.revision,
            "owner_name": item.owner_name,
            "review_due_at": utc(item.review_due_at).isoformat(),
            "unanswered": item.responded_at is None,
            "overdue": item.status not in CLOSED
            and utc(item.review_due_at) < datetime.now(timezone.utc),
            "practice": item.practice,
            "linked_to_id": str(item.linked_to_id) if item.linked_to_id else None,
            "knowledge_id": str(item.knowledge_id) if item.knowledge_id else None,
            "interact_id": str(item.interact_id) if item.interact_id else None,
            "can_manage": await self.manager(item),
            "can_contribute": self.realm != "group" or self.member.role != "viewer",
            "following": follower is not None,
            "unread": follower is not None and follower.seen_revision < item.revision,
            "created_at": utc(item.created_at).isoformat(),
        }

    async def detail(self, item_id, offset=0):
        item = await self.item(item_id)
        response = await self.summary(item)
        events = list(
            await self.session.scalars(
                select(BankActivity)
                .where(BankActivity.suggestion_id == item.id)
                .order_by(BankActivity.revision.desc(), BankActivity.created_at.desc())
                .offset(offset)
                .limit(51)
            )
        )
        response["activities"] = [
            {
                "id": str(e.id),
                "actor_name": e.actor_name,
                "action": e.action,
                "text": e.text,
                "revision": e.revision,
                "created_at": utc(e.created_at).isoformat(),
            }
            for e in events[:50]
        ]
        response["more_activities"] = len(events) > 50
        await self.session.commit()
        return response

    async def seen(self, item_id, revision):
        item = await self.item(item_id, lock=True)
        follower = await self.session.scalar(
            select(BankFollower).where(
                BankFollower.suggestion_id == item.id,
                BankFollower.actor_key == self.key,
            )
        )
        if follower:
            follower.seen_revision = max(
                follower.seen_revision, min(revision, item.revision)
            )
        await self.session.commit()
        return {"ok": True}

    async def reviewers(self, scope: BankScope):
        audience = await self.scope(scope)
        probe = BankSuggestion(**audience)
        if self.realm == "group":
            candidates = list(
                await self.session.scalars(
                    select(GuestGroupMembership)
                    .where(
                        GuestGroupMembership.group_id == scope.scope_id,
                        GuestGroupMembership.status == "active",
                        GuestGroupMembership.role == "admin",
                    )
                    .limit(200)
                )
            )
            return [{"id": str(m.id), "name": m.display_name} for m in candidates]
        users = list(
            await self.session.scalars(
                select(User)
                .where(
                    User.organisation_id == self.actor.organisation_id,
                    User.status == "active",
                )
                .order_by(User.display_name)
                .limit(200)
            )
        )
        result = []
        original = self.actor
        try:
            for user in users:
                self.actor = user
                self._manager_cache = {}
                visible = (
                    audience["scope_type"] == "organisation"
                    or (
                        audience["scope_type"] == "department"
                        and user.department_id == audience["department_id"]
                    )
                    or (
                        audience["scope_type"] == "team"
                        and await self.session.scalar(
                            select(TeamMembership.id).where(
                                TeamMembership.team_id == audience["team_id"],
                                TeamMembership.organisation_id == user.organisation_id,
                                TeamMembership.user_id == user.id,
                            )
                        )
                    )
                )
                if visible and await self.manager(probe):
                    result.append({"id": str(user.id), "name": user.display_name})
        finally:
            self.actor = original
            self._manager_cache = {}
        return result

    async def act(self, item_id, payload: BankAction):
        item = await self.item(item_id, lock=True)
        self.require_contributor()
        fingerprint = sha256(
            json.dumps(
                payload.model_dump(mode="json", exclude={"expected_revision"}),
                sort_keys=True,
            ).encode()
        ).hexdigest()
        previous = await self.session.scalar(
            select(BankActivity).where(
                BankActivity.suggestion_id == item.id,
                BankActivity.actor_key == self.key,
                BankActivity.client_key == payload.client_key,
            )
        )
        if previous:
            if (
                previous.action != payload.action
                or previous.request_hash != fingerprint
            ):
                raise ConflictError("This action key was already used")
            await self.session.commit()
            return await self.detail(item.id)
        if item.revision != payload.expected_revision:
            raise ConflictError(
                "This suggestion changed. Refresh and review the latest update before retrying."
            )
        action = payload.action
        if action == "support" and await self.session.scalar(
            select(BankActivity.id)
            .where(
                BankActivity.suggestion_id == item.id,
                BankActivity.actor_key == self.key,
                BankActivity.action == "support",
            )
            .limit(1)
        ):
            return await self.detail(item.id)
        if action not in {"comment", "support"}:
            await self.require_manager(item)
            if not payload.text:
                raise HTTPException(422, "Explain the response or decision")
        elif action == "comment" and not payload.text:
            raise HTTPException(422, "Write your comment or example")
        if action == "status":
            if payload.status not in TRANSITIONS[item.status]:
                raise ConflictError(
                    "Review this suggestion before making that status change"
                )
            if (
                payload.status in {"planned", "in_progress", "implemented"}
                and not item.owner_key
            ):
                raise ConflictError("Assign an accountable reviewer first")
            if payload.status in {"planned", "in_progress", "implemented"}:
                reviewers = await self.reviewers(self.scope_of(item))
                active_owner = False
                for reviewer in reviewers:
                    if (
                        self.realm == "organisation"
                        and item.owner_key == "org:" + reviewer["id"]
                    ):
                        active_owner = True
                    elif self.realm == "group":
                        member = await self.session.get(
                            GuestGroupMembership, UUID(reviewer["id"])
                        )
                        active_owner = (
                            active_owner
                            or item.owner_key == "group:" + member.firebase_uid
                        )
                if not active_owner:
                    raise ConflictError(
                        "The assigned reviewer no longer has authority. Reassign before progressing."
                    )
            item.status = payload.status
        elif action == "assign":
            options = await self.reviewers(self.scope_of(item))
            target = next(
                (o for o in options if o["id"] == str(payload.target_id)), None
            )
            if target is None:
                raise PermissionDeniedError(
                    "Select an active reviewer with access and authority for this audience"
                )
            if self.realm == "group":
                member = await self.session.get(GuestGroupMembership, payload.target_id)
                item.owner_key = "group:" + member.firebase_uid
            else:
                item.owner_key = "org:" + str(payload.target_id)
            item.owner_name = target["name"]
            if payload.review_due_at is None or payload.review_due_at <= datetime.now(
                timezone.utc
            ):
                raise HTTPException(422, "Choose a future review date")
            item.review_due_at = payload.review_due_at
        elif action in {"adopt_practice", "revise_practice"}:
            if item.status not in {"planned", "in_progress", "implemented"}:
                raise ConflictError(
                    "Agree and assign the proposal before adopting a practice"
                )
            if action == "revise_practice" and not item.practice:
                raise ConflictError("No adopted practice to revise")
            if action == "adopt_practice" and item.practice:
                raise ConflictError("Revise the existing practice instead")
            item.practice = payload.text
        elif action == "withdraw_practice":
            if not item.practice:
                raise ConflictError("No adopted practice to withdraw")
            item.practice = None
        elif action == "link_duplicate":
            target = (
                await self.item(payload.target_id, lock=True)
                if payload.target_id
                else None
            )
            if (
                target is None
                or target.id == item.id
                or target.linked_to_id
                or self.scope_of(target) != self.scope_of(item)
            ):
                raise ConflictError(
                    "Link to an original suggestion in the same audience"
                )
            # No reassignment of authorship, deletion or hidden audience expansion.
            if await self.session.scalar(
                select(BankSuggestion.id)
                .where(BankSuggestion.linked_to_id == item.id)
                .limit(1)
            ):
                raise ConflictError(
                    "Link this suggestion's existing duplicates to the original first"
                )
            item.linked_to_id = target.id
        elif action == "unlink_duplicate":
            item.linked_to_id = None
        elif action == "escalate":
            if (
                not payload.target_scope
                or not payload.confirm_visibility
                or payload.target_scope == self.scope_of(item)
            ):
                raise ConflictError(
                    "Choose a different destination and confirm its audience"
                )
            source_scope = self.scope_of(item)
            audience = await self.scope(payload.target_scope)
            if (
                payload.target_scope.scope_type == "group"
                and source_scope.scope_type != "group"
                or payload.target_scope.scope_type != "group"
                and source_scope.scope_type == "group"
            ):
                raise PermissionDeniedError(
                    "Organisation and Group content stay separate"
                )
            self.require_contributor()
            copy = BankSuggestion(
                **audience,
                kind=item.kind,
                title=item.title,
                problem=item.problem,
                proposal=item.proposal,
                benefit=item.benefit,
                author_key=self.key,
                author_name=self.name,
                client_key=sha256(
                    (str(item.id) + payload.client_key).encode()
                ).hexdigest(),
                review_due_at=datetime.now(timezone.utc) + timedelta(days=7)
            )
            self.session.add(copy)
            await self.session.flush()
            self.session.add(
                BankActivity(
                    suggestion_id=copy.id,
                    actor_key=self.key,
                    actor_name=self.name,
                    client_key=payload.client_key,
                    action="escalated",
                    text="Escalated proposal. " + payload.text,
                    revision=1,
                )
            )
            self.session.add(
                BankFollower(suggestion_id=copy.id, actor_key=self.key, seen_revision=0)
            )
            payload.text += " · Destination suggestion: " + str(copy.id)
            await self.scope(source_scope)
        elif action == "link_knowledge":
            if self.realm != "organisation" or payload.target_id is None:
                raise ConflictError("Choose approved organisational Knowledge")
            question = await self.session.scalar(
                select(Question).where(
                    Question.id == payload.target_id,
                    Question.organisation_id == self.actor.organisation_id,
                    PermissionService.question_visibility_clause(self.actor),
                )
            )
            if (
                question is None
                or question.visibility.value != item.scope_type
                or (
                    item.scope_type == "department"
                    and question.department_id != item.department_id
                )
                or (item.scope_type == "team" and question.team_id != item.team_id)
            ):
                raise PermissionDeniedError(
                    "Knowledge must have the same audience as this suggestion"
                )
            verified = await self.session.scalar(
                select(Answer.id)
                .where(
                    Answer.question_id == question.id,
                    Answer.organisation_id == self.actor.organisation_id,
                    Answer.status == AnswerStatus.VERIFIED,
                )
                .limit(1)
            )
            if not verified:
                raise ConflictError("Use Knowledge with an approved verified answer")
            item.knowledge_id = question.id
        elif action == "start_interact":
            if item.status not in {"planned", "in_progress", "implemented"}:
                raise ConflictError("Agree the proposal before starting the review")
            if item.interact_id:
                raise ConflictError("This suggestion already has an Interact review")
            if self.realm == "group":
                from app.models.guest import GuestGroupEntry
                from app.services.guest import MAX_GUEST_GROUP_ENTRIES

                if (
                    await self.guest.guest.entry_count(item.group_id)
                    >= MAX_GUEST_GROUP_ENTRIES
                ):
                    raise HTTPException(429, "Group storage limit reached")
                from uuid import uuid4

                review_id = uuid4()
                data = {
                    "id": str(review_id),
                    "title": "Review: " + item.title,
                    "visibility": "group",
                    "status": "draft",
                    "source_suggestion_id": str(item.id),
                    "participants": [],
                    "questions": [
                        {
                            "id": str(uuid4()),
                            "text": text,
                            "scope": "shared",
                            "answers": [],
                            "follow_ups": [],
                        }
                        for text in [
                            "Problem: " + item.problem,
                            "Proposed change: " + item.proposal,
                            "Expected benefit: " + item.benefit,
                            "What evidence and outcome should be recorded as Knowledge?",
                        ]
                    ],
                }
                await self.guest._check_group_storage(
                    item.group_id, len(json.dumps(data).encode())
                )
                review = GuestGroupEntry(
                    id=review_id,
                    group_id=item.group_id,
                    kind="interact_session",
                    title=data["title"][:500],
                    data=data,
                    created_by_uid=self.identity.firebase_uid,
                    updated_by_uid=self.identity.firebase_uid,
                    revision=1,
                )
                self.session.add(review)
                item.interact_id = review_id
            else:
                from app.models.guided import (
                    GuidedSession,
                    GuidedSessionStatus,
                    GuidedSessionVisibility,
                    GuidedQuestion,
                    GuidedQuestionScope,
                    GuidedQuestionSource,
                )

                review = GuidedSession(
                    organisation_id=self.actor.organisation_id,
                    created_by=self.actor.id,
                    title=("Review: " + item.title)[:500],
                    context_reference="/suggestions/" + str(item.id),
                    department_id=item.department_id,
                    team_id=item.team_id,
                    visibility=GuidedSessionVisibility(item.scope_type),
                    status=GuidedSessionStatus.DRAFT,
                    revision=1,
                )
                self.session.add(review)
                await self.session.flush()
                for index, text in enumerate(
                    [
                        "Problem: " + item.problem,
                        "Proposed change: " + item.proposal,
                        "Expected benefit: " + item.benefit,
                        "What evidence and decision should be captured as approved Knowledge?",
                    ]
                ):
                    self.session.add(
                        GuidedQuestion(
                            organisation_id=self.actor.organisation_id,
                            session_id=review.id,
                            text=text,
                            scope=GuidedQuestionScope.SHARED,
                            source=GuidedQuestionSource.MANUAL,
                            main_order_index=index,
                            created_by=self.actor.id,
                        )
                    )
                item.interact_id = review.id
                from app.services.guided import GuidedService
                from app.models.audit_event import AuditAction

                await GuidedService(self.session)._audit(
                    self.actor.organisation_id,
                    self.actor.id,
                    AuditAction.GUIDED_SESSION_CREATED,
                    "guided_session",
                    review.id,
                    {"source": "suggestion_bank", "suggestion_id": str(item.id)},
                )
        if action not in {"comment", "support"}:
            item.responded_at = datetime.now(timezone.utc)
        # CAS also protects SQLite tests and concurrent clients without row locks.
        old = item.revision
        result = await self.session.execute(
            update(BankSuggestion)
            .where(BankSuggestion.id == item.id, BankSuggestion.revision == old)
            .values(revision=old + 1)
        )
        if result.rowcount != 1:
            raise ConflictError("This suggestion changed. Refresh before retrying.")
        item.revision = old + 1
        self.session.add(
            BankActivity(
                suggestion_id=item.id,
                actor_key=self.key,
                actor_name=self.name,
                client_key=payload.client_key,
                request_hash=fingerprint,
                action=action,
                text=payload.text or "Supports this suggestion",
                revision=item.revision,
            )
        )
        follower = await self.session.scalar(
            select(BankFollower).where(
                BankFollower.suggestion_id == item.id,
                BankFollower.actor_key == self.key,
            )
        )
        if follower is None:
            self.session.add(
                BankFollower(suggestion_id=item.id, actor_key=self.key, seen_revision=0)
            )
        if item.owner_key:
            owner_follow = await self.session.scalar(
                select(BankFollower.id).where(
                    BankFollower.suggestion_id == item.id,
                    BankFollower.actor_key == item.owner_key,
                )
            )
            if not owner_follow and item.owner_key != self.key:
                self.session.add(
                    BankFollower(
                        suggestion_id=item.id, actor_key=item.owner_key, seen_revision=0
                    )
                )
        await self.session.commit()
        return await self.detail(item.id)

    async def nia(self, scope: BankScope, query: str):
        audience = await self.scope(scope)
        stmt = select(BankSuggestion).where(
            *(getattr(BankSuggestion, k) == v for k, v in audience.items())
        )
        # Bounded lexical/typo matching only; no embedding/provider calls.
        words = [w for w in query.lower().split() if len(w) > 2][:12]
        candidates = list(
            await self.session.scalars(
                stmt.order_by(BankSuggestion.created_at.desc()).limit(200)
            )
        )

        def score(item):
            text = (item.title + " " + item.proposal).lower()
            return (
                sum(w in text for w in words)
                + SequenceMatcher(None, query.lower(), item.title.lower()).ratio()
            )

        matches = sorted(candidates, key=score, reverse=True)
        related = [
            await self.summary(i) for i in matches if query and score(i) >= 0.45
        ][:5]
        knowledge = []
        if self.realm == "organisation" and words:
            qs = (
                select(Question)
                .where(
                    Question.organisation_id == self.actor.organisation_id,
                    PermissionService.question_visibility_clause(self.actor),
                    Question.canonical_question_id.is_(None),
                    select(Answer.id)
                    .where(
                        Answer.question_id == Question.id,
                        Answer.organisation_id == Question.organisation_id,
                        Answer.status == AnswerStatus.VERIFIED,
                    )
                    .exists(),
                    or_(
                        *(
                            Question.title.ilike(
                                "%"
                                + w.replace("!", "!!")
                                .replace("%", "!%")
                                .replace("_", "!_")
                                + "%",
                                escape="!",
                            )
                            for w in words
                        )
                    ),
                )
                .limit(5)
            )
            knowledge = [
                {"id": str(q.id), "title": q.title}
                for q in await self.session.scalars(qs)
            ]
        result = {
            "related": related,
            "knowledge": knowledge,
            "method": "Scoped keyword and typo matching; no automatic decisions",
            "prompts": [],
        }
        await self.session.commit()
        return result
