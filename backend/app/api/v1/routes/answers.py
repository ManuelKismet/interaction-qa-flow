from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.schemas.answer import (
    AnswerDetailResponse,
    AnswerRestoreRequest,
    AnswerResponse,
    AnswerUpdate,
    ReactionCreate,
    ReactionResponse,
)
from app.schemas.governance import (
    AnswerChallengeResponse,
    AnswerVersionResponse,
    ChallengeCreate,
    ReviewAnswerRequest,
    VerifyAnswerRequest,
)
from app.services.answer import AnswerService
from app.services.governance import GovernanceService

router = APIRouter(prefix="/answers", tags=["answers"])


@router.post("/{answer_id}/verify", response_model=AnswerResponse)
async def verify_answer(
    answer_id: UUID,
    payload: VerifyAnswerRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerResponse:
    return await GovernanceService(session, settings).verify(
        answer_id, identity.organisation_id, identity.user_id, payload
    )


@router.post("/{answer_id}/unverify", response_model=AnswerResponse)
async def unverify_answer(
    answer_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerResponse:
    return await GovernanceService(session, settings).unverify(
        answer_id, identity.organisation_id, identity.user_id
    )


@router.post("/{answer_id}/review", response_model=AnswerResponse)
async def review_answer(
    answer_id: UUID,
    payload: ReviewAnswerRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerResponse:
    return await GovernanceService(session, settings).review(
        answer_id, identity.organisation_id, identity.user_id, payload
    )


@router.post(
    "/{answer_id}/challenges",
    response_model=AnswerChallengeResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_challenge(
    answer_id: UUID,
    payload: ChallengeCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> AnswerChallengeResponse:
    return await GovernanceService(session, settings).create_challenge(
        answer_id, identity.organisation_id, identity.user_id, payload
    )


@router.get("/{answer_id}/challenges", response_model=list[AnswerChallengeResponse])
async def list_challenges(
    answer_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[AnswerChallengeResponse]:
    return await GovernanceService(session, settings).list_challenges(
        answer_id, identity.organisation_id, identity.user_id
    )


@router.get("/{answer_id}/versions", response_model=list[AnswerVersionResponse])
async def list_versions(
    answer_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[AnswerVersionResponse]:
    return await GovernanceService(session, settings).versions(
        answer_id, identity.organisation_id, identity.user_id
    )


@router.patch("/{answer_id}", response_model=AnswerDetailResponse)
async def update_answer(
    answer_id: UUID,
    payload: AnswerUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> AnswerDetailResponse:
    return await AnswerService(session).update(
        answer_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.delete("/{answer_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_answer(
    answer_id: UUID,
    reason: str | None = Query(default=None, max_length=4000),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await AnswerService(session).delete(
        answer_id,
        identity.organisation_id,
        identity.user_id,
        reason,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{answer_id}/restore", response_model=AnswerDetailResponse)
async def restore_answer(
    answer_id: UUID,
    payload: AnswerRestoreRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> AnswerDetailResponse:
    return await AnswerService(session).restore(
        answer_id,
        identity.organisation_id,
        identity.user_id,
        payload,
    )


@router.post("/{answer_id}/reaction", response_model=ReactionResponse)
async def react_to_answer(
    answer_id: UUID,
    payload: ReactionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> ReactionResponse:
    return await AnswerService(session).react(
        answer_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )