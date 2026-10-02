from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from app.ai.embedding_provider import get_embedding_provider
from app.api.dependencies import (
    AuthenticatedIdentity,
    DevelopmentIdentity,
    get_development_identity,
)
from app.core.config import Settings, get_settings
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models.question import QuestionStatus
from app.schemas.answer import AnswerCreate, AnswerDetailResponse
from app.schemas.canonical import (
    DuplicateSuggestionCreate,
    DuplicateSuggestionResponse,
    MergeQuestionsRequest,
    MergeQuestionsResponse,
    UnmergeQuestionRequest,
)
from app.schemas.comment import CommentCreate, CommentResponse
from app.schemas.question import (
    ArchiveQuestionRequest,
    QuestionChangeRequestCreate,
    QuestionChangeRequestResponse,
    QuestionChangeRequestReview,
    QuestionAction,
    QuestionCreate,
    QuestionDetailResponse,
    QuestionListItem,
    QuestionResolve,
    QuestionResponse,
    QuestionUpdate,
    QuestionVersionResponse,
    RestoreQuestionRequest,
)
from app.schemas.search import SemanticSearchRequest, SemanticSearchResult
from app.services.answer import AnswerService
from app.services.canonical import CanonicalQuestionService
from app.services.comment import CommentService
from app.services.question import QuestionService
from app.services.search import SearchService

router = APIRouter(prefix="/questions", tags=["questions"])


@router.get(
    "/{question_id}/duplicate-candidates",
    response_model=list[SemanticSearchResult],
)
async def duplicate_candidates(
    question_id: UUID,
    limit: int = Query(default=3, ge=1, le=5),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[SemanticSearchResult]:
    return await CanonicalQuestionService(
        session, settings, get_embedding_provider(settings)
    ).candidates(
        question_id, identity.organisation_id, identity.user_id, limit
    )


@router.post(
    "/{question_id}/duplicate-suggestions",
    response_model=DuplicateSuggestionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def suggest_duplicate(
    question_id: UUID,
    payload: DuplicateSuggestionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> DuplicateSuggestionResponse:
    return await CanonicalQuestionService(session, settings).suggest(
        question_id, identity.organisation_id, identity.user_id, payload
    )


@router.post(
    "/{canonical_question_id}/merge",
    response_model=MergeQuestionsResponse,
)
async def merge_questions(
    canonical_question_id: UUID,
    payload: MergeQuestionsRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> MergeQuestionsResponse:
    return await CanonicalQuestionService(session, settings).merge(
        canonical_question_id,
        identity.organisation_id,
        identity.user_id,
        payload,
    )


@router.post("/{question_id}/unmerge", response_model=QuestionResponse)
async def unmerge_question(
    question_id: UUID,
    payload: UnmergeQuestionRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await CanonicalQuestionService(session, settings).unmerge(
        question_id,
        identity.organisation_id,
        identity.user_id,
        payload.reason,
    )


@router.post("/search", response_model=list[SemanticSearchResult])
async def search_questions(
    payload: SemanticSearchRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[SemanticSearchResult]:
    return await SearchService(
        session,
        get_embedding_provider(settings),
        settings,
    ).search(
        query=payload.query,
        limit=payload.limit,
        organisation_id=identity.organisation_id,
        user_id=identity.user_id,
        include_unanswered=payload.include_unanswered,
    )


@router.get(
    "/change-requests",
    response_model=list[QuestionChangeRequestResponse],
)
async def list_question_change_requests(
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[QuestionChangeRequestResponse]:
    return await QuestionService(session).list_change_requests(
        identity.organisation_id, identity.user_id
    )


@router.post(
    "/change-requests/{request_id}/review",
    response_model=QuestionChangeRequestResponse,
)
async def review_question_change_request(
    request_id: UUID,
    payload: QuestionChangeRequestReview,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionChangeRequestResponse:
    return await QuestionService(session).review_change_request(
        request_id,
        identity.organisation_id,
        identity.user_id,
        payload,
    )


@router.post("", response_model=QuestionResponse, status_code=status.HTTP_201_CREATED)
async def create_question(
    payload: QuestionCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).create(
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "author_id": identity.user_id,
            }
        )
    )


@router.get("", response_model=list[QuestionListItem])
async def list_questions(
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    status_filter: QuestionStatus | None = Query(default=None, alias="status"),
    department_id: UUID | None = None,
    team_id: UUID | None = None,
    author_id: UUID | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[QuestionListItem]:
    return await QuestionService(session).list(
        identity.organisation_id,
        identity.user_id,
        offset,
        limit,
        status_filter,
        department_id,
        team_id,
        author_id,
    )


@router.get(
    "/{question_id}/versions",
    response_model=list[QuestionVersionResponse],
)
async def list_question_versions(
    question_id: UUID,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[QuestionVersionResponse]:
    return await QuestionService(session).list_versions(
        question_id,
        identity.organisation_id,
        identity.user_id,
    )


@router.post(
    "/{question_id}/change-requests",
    response_model=QuestionChangeRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_question_change_request(
    question_id: UUID,
    payload: QuestionChangeRequestCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionChangeRequestResponse:
    return await QuestionService(session).request_change(
        question_id,
        identity.organisation_id,
        identity.user_id,
        payload,
    )


@router.get("/{question_id}", response_model=QuestionDetailResponse)
async def get_question(
    question_id: UUID,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionDetailResponse:
    return await QuestionService(session).get(
        question_id, identity.organisation_id, identity.user_id
    )


@router.patch("/{question_id}", response_model=QuestionResponse)
async def update_question(
    question_id: UUID,
    payload: QuestionUpdate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).update(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.post("/{question_id}/resolve", response_model=QuestionResponse)
async def resolve_question(
    question_id: UUID,
    payload: QuestionResolve,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).resolve(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.post("/{question_id}/reopen", response_model=QuestionResponse)
async def reopen_question(
    question_id: UUID,
    payload: QuestionAction,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).reopen(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.post("/{question_id}/archive", response_model=QuestionResponse)
async def archive_question(
    question_id: UUID,
    payload: ArchiveQuestionRequest,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).archive(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.post("/{question_id}/restore", response_model=QuestionResponse)
async def restore_question(
    question_id: UUID,
    payload: RestoreQuestionRequest,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> QuestionResponse:
    return await QuestionService(session).restore(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "user_id": identity.user_id,
            }
        ),
    )


@router.post(
    "/{question_id}/answers",
    response_model=AnswerDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_answer(
    question_id: UUID,
    payload: AnswerCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> AnswerDetailResponse:
    return await AnswerService(session).create(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "author_id": identity.user_id,
            }
        ),
    )


@router.get("/{question_id}/answers", response_model=list[AnswerDetailResponse])
async def list_answers(
    question_id: UUID,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[AnswerDetailResponse]:
    return await AnswerService(session).list(
        question_id, identity.organisation_id, identity.user_id
    )


@router.post(
    "/{question_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_comment(
    question_id: UUID,
    payload: CommentCreate,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> CommentResponse:
    return await CommentService(session).create(
        question_id,
        payload.model_copy(
            update={
                "organisation_id": identity.organisation_id,
                "author_id": identity.user_id,
            }
        ),
    )


@router.get("/{question_id}/comments", response_model=list[CommentResponse])
async def list_comments(
    question_id: UUID,
    identity: AuthenticatedIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[CommentResponse]:
    return await CommentService(session).list(
        question_id, identity.organisation_id, identity.user_id
    )