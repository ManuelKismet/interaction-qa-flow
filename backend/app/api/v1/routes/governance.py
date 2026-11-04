from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.models.answer_challenge import ChallengeStatus
from app.schemas.governance import (
    AnswerChallengeResponse,
    AuditEventResponse,
    ChallengeDecision,
    DepartmentAnswerOwnerCreate,
    DepartmentAnswerOwnerResponse,
    ReviewQueueItem,
    ReviewQueueType,
)
from app.schemas.canonical import DuplicateSuggestionDecision, DuplicateSuggestionResponse
from app.services.canonical import CanonicalQuestionService
from app.services.governance import GovernanceService

router = APIRouter(tags=["governance"])


@router.post(
    "/duplicate-suggestions/{suggestion_id}/accept",
    response_model=DuplicateSuggestionResponse,
)
async def accept_duplicate_suggestion(
    suggestion_id: UUID,
    payload: DuplicateSuggestionDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> DuplicateSuggestionResponse:
    return await CanonicalQuestionService(session, settings).decide_suggestion(
        suggestion_id,
        identity.organisation_id,
        identity.user_id,
        payload,
        accept=True,
    )


@router.post(
    "/duplicate-suggestions/{suggestion_id}/reject",
    response_model=DuplicateSuggestionResponse,
)
async def reject_duplicate_suggestion(
    suggestion_id: UUID,
    payload: DuplicateSuggestionDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> DuplicateSuggestionResponse:
    return await CanonicalQuestionService(session, settings).decide_suggestion(
        suggestion_id,
        identity.organisation_id,
        identity.user_id,
        payload,
        accept=False,
    )


@router.get("/review-queue", response_model=list[ReviewQueueItem])
async def review_queue(
    department_id: UUID | None = None,
    item_type: ReviewQueueType | None = Query(default=None, alias="type"),
    challenge_status: ChallengeStatus | None = Query(default=None, alias="status"),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[ReviewQueueItem]:
    return await GovernanceService(session, settings).review_queue(
        identity.organisation_id,
        identity.user_id,
        department_id,
        item_type,
        challenge_status,
    )


@router.post(
    "/challenges/{challenge_id}/accept",
    response_model=AnswerChallengeResponse,
)
async def accept_challenge(
    challenge_id: UUID,
    payload: ChallengeDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerChallengeResponse:
    return await GovernanceService(session, settings).decide_challenge(
        challenge_id,
        identity.organisation_id,
        identity.user_id,
        payload,
        accept=True,
    )


@router.post(
    "/challenges/{challenge_id}/reject",
    response_model=AnswerChallengeResponse,
)
async def reject_challenge(
    challenge_id: UUID,
    payload: ChallengeDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerChallengeResponse:
    return await GovernanceService(session, settings).decide_challenge(
        challenge_id,
        identity.organisation_id,
        identity.user_id,
        payload,
        accept=False,
    )


@router.get(
    "/department-answer-owners",
    response_model=list[DepartmentAnswerOwnerResponse],
)
async def list_department_answer_owners(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[DepartmentAnswerOwnerResponse]:
    return await GovernanceService(session, settings).list_department_owners(
        identity.organisation_id, identity.user_id
    )


@router.get("/department-answer-owners/mine", response_model=list[UUID])
async def list_my_department_answer_owner_ids(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[UUID]:
    return await GovernanceService(session, settings).my_department_owner_ids(
        identity.organisation_id, identity.user_id
    )


@router.post(
    "/departments/{department_id}/answer-owners",
    response_model=DepartmentAnswerOwnerResponse,
    status_code=status.HTTP_201_CREATED,
)
async def assign_department_answer_owner(
    department_id: UUID,
    payload: DepartmentAnswerOwnerCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> DepartmentAnswerOwnerResponse:
    return await GovernanceService(session, settings).assign_department_owner(
        department_id,
        identity.organisation_id,
        identity.user_id,
        payload.user_id,
    )


@router.delete(
    "/departments/{department_id}/answer-owners/{owner_user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_department_answer_owner(
    department_id: UUID,
    owner_user_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GovernanceService(session, settings).remove_department_owner(
        department_id,
        owner_user_id,
        identity.organisation_id,
        identity.user_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/audit-events", response_model=list[AuditEventResponse])
async def list_audit_events(
    limit: int = Query(default=100, ge=1, le=500),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[AuditEventResponse]:
    return await GovernanceService(session, settings).audit_events(
        identity.organisation_id, identity.user_id, limit
    )