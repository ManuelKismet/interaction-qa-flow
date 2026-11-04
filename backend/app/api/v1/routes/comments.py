from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.database import get_session
from app.schemas.comment import CommentResponse, CommentUpdate
from app.services.comment import CommentService

router = APIRouter(prefix="/comments", tags=["comments"])


@router.patch("/{comment_id}", response_model=CommentResponse)
async def update_comment(
    comment_id: UUID,
    payload: CommentUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> CommentResponse:
    return await CommentService(session).update(
        comment_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.delete("/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_comment(
    comment_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await CommentService(session).delete(
        comment_id,
        identity.organisation_id,
        identity.user_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)