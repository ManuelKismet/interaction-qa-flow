from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from fastapi.responses import JSONResponse, PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embedding_provider import get_embedding_provider
from app.api.dependencies import DevelopmentIdentity, get_development_identity
from app.core.config import Settings, get_settings
from app.core.database import get_session
from app.models.guided import GuidedSessionStatus
from app.schemas.guided import (
    GuidedAnswerResponse,
    GuidedAnswerUpdate,
    GuidedAnswerUpsert,
    GuidedFollowUpCreate,
    GuidedKnowledgeSearch,
    GuidedParticipantCreate,
    GuidedParticipantResponse,
    GuidedParticipantUpdate,
    GuidedQuestionCreate,
    GuidedQuestionResponse,
    GuidedQuestionUpdate,
    GuidedRevisionResponse,
    GuidedSessionCreate,
    GuidedSessionResponse,
    GuidedSessionSummary,
    GuidedSessionUpdate,
    GuidedTemplateCreate,
    GuidedTemplateImportRequest,
    GuidedTemplateResponse,
    GuidedTemplateUpdate,
    GuidedTemplateVersionCreate,
    GuidedViewMode,
    KnowledgeProposalCreate,
    KnowledgeProposalDecision,
    KnowledgeProposalResponse,
    LegacyImportRequest,
    LegacyImportResponse,
)
from app.schemas.search import SemanticSearchResult
from app.services.guided import GuidedService
from app.services.interact_search import InteractSearchService
from app.services.guided_knowledge import GuidedKnowledgeService

router = APIRouter(prefix="/guided", tags=["guided"])


@router.get("/templates", response_model=list[GuidedTemplateResponse])
async def list_templates(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[GuidedTemplateResponse]:
    return await GuidedService(session).list_templates(identity.organisation_id, identity.user_id)


@router.post("/templates", response_model=GuidedTemplateResponse, status_code=status.HTTP_201_CREATED)
async def create_template(
    payload: GuidedTemplateCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).create_template(identity.organisation_id, identity.user_id, payload)


@router.get("/templates/export/all")
async def export_templates(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> JSONResponse:
    payload = await GuidedService(session).export_templates(identity.organisation_id, identity.user_id)
    return JSONResponse(payload, headers={"Content-Disposition": 'attachment; filename="guided-templates.json"'})


@router.post("/templates/import", response_model=list[GuidedTemplateResponse])
async def import_templates(
    payload: GuidedTemplateImportRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[GuidedTemplateResponse]:
    return await GuidedService(session).import_templates(identity.organisation_id, identity.user_id, payload)


@router.get("/templates/{template_id}", response_model=GuidedTemplateResponse)
async def get_template(
    template_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).get_template(template_id, identity.organisation_id, identity.user_id)


@router.patch("/templates/{template_id}", response_model=GuidedTemplateResponse)
async def update_template(
    template_id: UUID,
    payload: GuidedTemplateUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).update_template(template_id, identity.organisation_id, identity.user_id, payload)


@router.post("/templates/{template_id}/versions", response_model=GuidedTemplateResponse)
async def version_template(
    template_id: UUID,
    payload: GuidedTemplateVersionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).version_template(template_id, identity.organisation_id, identity.user_id, payload)


@router.post("/templates/{template_id}/duplicate", response_model=GuidedTemplateResponse)
async def duplicate_template(
    template_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).duplicate_template(template_id, identity.organisation_id, identity.user_id)


@router.post("/templates/{template_id}/archive", response_model=GuidedTemplateResponse)
async def archive_template(
    template_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).archive_template(template_id, identity.organisation_id, identity.user_id)


@router.post("/templates/{template_id}/restore", response_model=GuidedTemplateResponse)
async def restore_template(
    template_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedTemplateResponse:
    return await GuidedService(session).restore_template(template_id, identity.organisation_id, identity.user_id)


@router.get("/sessions", response_model=list[GuidedSessionSummary])
async def list_sessions(
    status_filter: GuidedSessionStatus | None = Query(default=None, alias="status"),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[GuidedSessionSummary]:
    return await GuidedService(session).list_sessions(identity.organisation_id, identity.user_id, status_filter)


@router.post("/sessions", response_model=GuidedSessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    payload: GuidedSessionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await GuidedService(session).create_session(identity.organisation_id, identity.user_id, payload)


@router.get("/sessions/search")
async def search_interact_sessions(
    query: str = Query(min_length=2, max_length=100),
    limit: int = Query(default=25, ge=1, le=50),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> dict:
    return await InteractSearchService(session).organisation(
        identity.organisation_id, identity.user_id, query, limit=limit
    )


@router.get("/sessions/{session_id}", response_model=GuidedSessionResponse)
async def get_guided_session(
    session_id: UUID,
    participant_id: UUID | None = None,
    view_mode: GuidedViewMode = GuidedViewMode.ALL_RELEVANT,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await GuidedService(session).get_session(
        session_id, identity.organisation_id, identity.user_id, participant_id, view_mode
    )


@router.patch("/sessions/{session_id}", response_model=GuidedSessionResponse)
async def update_guided_session(
    session_id: UUID,
    payload: GuidedSessionUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await GuidedService(session).update_session(session_id, identity.organisation_id, identity.user_id, payload)


async def transition(
    session_id: UUID,
    target: GuidedSessionStatus,
    identity: DevelopmentIdentity,
    session: AsyncSession,
) -> GuidedSessionResponse:
    return await GuidedService(session).transition_session(session_id, identity.organisation_id, identity.user_id, target)


@router.post("/sessions/{session_id}/start", response_model=GuidedSessionResponse)
async def start_session(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await transition(session_id, GuidedSessionStatus.ACTIVE, identity, session)


@router.post("/sessions/{session_id}/complete", response_model=GuidedSessionResponse)
async def complete_session(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await transition(session_id, GuidedSessionStatus.COMPLETED, identity, session)


@router.post("/sessions/{session_id}/archive", response_model=GuidedSessionResponse)
async def archive_session(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedSessionResponse:
    return await transition(session_id, GuidedSessionStatus.ARCHIVED, identity, session)


@router.get("/sessions/{session_id}/revisions", response_model=list[GuidedRevisionResponse])
async def revisions(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[GuidedRevisionResponse]:
    return await GuidedService(session).revisions(session_id, identity.organisation_id, identity.user_id)


@router.post("/sessions/{session_id}/participants", response_model=GuidedParticipantResponse, status_code=status.HTTP_201_CREATED)
async def add_participant(
    session_id: UUID,
    payload: GuidedParticipantCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedParticipantResponse:
    return await GuidedService(session).add_participant(session_id, identity.organisation_id, identity.user_id, payload)


@router.patch("/participants/{participant_id}", response_model=GuidedParticipantResponse)
async def update_participant(
    participant_id: UUID,
    payload: GuidedParticipantUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedParticipantResponse:
    return await GuidedService(session).update_participant(participant_id, identity.organisation_id, identity.user_id, payload)


@router.delete("/participants/{participant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_participant(
    participant_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> Response:
    await GuidedService(session).remove_participant(participant_id, identity.organisation_id, identity.user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/sessions/{session_id}/questions", response_model=GuidedQuestionResponse, status_code=status.HTTP_201_CREATED)
async def add_question(
    session_id: UUID,
    payload: GuidedQuestionCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedQuestionResponse:
    return await GuidedService(session).add_question(session_id, identity.organisation_id, identity.user_id, payload)


@router.patch("/questions/{question_id}", response_model=GuidedQuestionResponse)
async def update_question(
    question_id: UUID,
    payload: GuidedQuestionUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedQuestionResponse:
    return await GuidedService(session).update_question(question_id, identity.organisation_id, identity.user_id, payload)


@router.delete("/questions/{question_id}", response_model=GuidedQuestionResponse)
async def delete_question(
    question_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedQuestionResponse:
    return await GuidedService(session).set_question_deleted(question_id, identity.organisation_id, identity.user_id, True)


@router.post("/questions/{question_id}/restore", response_model=GuidedQuestionResponse)
async def restore_question(
    question_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedQuestionResponse:
    return await GuidedService(session).set_question_deleted(question_id, identity.organisation_id, identity.user_id, False)


@router.post("/questions/{question_id}/answers", response_model=GuidedAnswerResponse)
async def upsert_answer(
    question_id: UUID,
    payload: GuidedAnswerUpsert,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedAnswerResponse:
    return await GuidedService(session).upsert_answer(question_id, identity.organisation_id, identity.user_id, payload)


@router.patch("/answers/{answer_id}", response_model=GuidedAnswerResponse)
async def update_answer(
    answer_id: UUID,
    payload: GuidedAnswerUpdate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedAnswerResponse:
    return await GuidedService(session).update_answer(answer_id, identity.organisation_id, identity.user_id, payload)


@router.post("/answers/{answer_id}/follow-ups", response_model=GuidedQuestionResponse, status_code=status.HTTP_201_CREATED)
async def add_follow_up(
    answer_id: UUID,
    payload: GuidedFollowUpCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> GuidedQuestionResponse:
    return await GuidedService(session).add_follow_up(answer_id, identity.organisation_id, identity.user_id, payload)


@router.post("/questions/{question_id}/knowledge-search", response_model=list[SemanticSearchResult])
async def knowledge_search(
    question_id: UUID,
    payload: GuidedKnowledgeSearch,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[SemanticSearchResult]:
    return await GuidedKnowledgeService(session, settings, get_embedding_provider(settings)).search_question(
        question_id, identity.organisation_id, identity.user_id, payload.query, payload.limit
    )


@router.post("/knowledge-proposals", response_model=KnowledgeProposalResponse, status_code=status.HTTP_201_CREATED)
async def create_proposal(
    payload: KnowledgeProposalCreate,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> KnowledgeProposalResponse:
    return await GuidedKnowledgeService(session).create_proposal(identity.organisation_id, identity.user_id, payload)


@router.get("/knowledge-proposals", response_model=list[KnowledgeProposalResponse])
async def list_proposals(
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> list[KnowledgeProposalResponse]:
    return await GuidedKnowledgeService(session).list_proposals(identity.organisation_id, identity.user_id)


@router.get("/knowledge-proposals/{proposal_id}/duplicates", response_model=list[SemanticSearchResult])
async def proposal_duplicates(
    proposal_id: UUID,
    limit: int = Query(default=5, ge=1, le=10),
    identity: DevelopmentIdentity = Depends(get_development_identity),
    settings: Settings = Depends(get_settings),
    session: AsyncSession = Depends(get_session),
) -> list[SemanticSearchResult]:
    return await GuidedKnowledgeService(session, settings, get_embedding_provider(settings)).duplicates(
        proposal_id, identity.organisation_id, identity.user_id, limit
    )


@router.post("/knowledge-proposals/{proposal_id}", response_model=KnowledgeProposalResponse)
async def decide_proposal(
    proposal_id: UUID,
    payload: KnowledgeProposalDecision,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> KnowledgeProposalResponse:
    return await GuidedKnowledgeService(session).decide(proposal_id, identity.organisation_id, identity.user_id, payload)


@router.post("/import/legacy", response_model=LegacyImportResponse)
async def import_legacy(
    payload: LegacyImportRequest,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> LegacyImportResponse:
    return await GuidedService(session).import_legacy(identity.organisation_id, identity.user_id, payload.payload)


@router.get("/sessions/{session_id}/export/json")
async def export_json(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> JSONResponse:
    payload = await GuidedService(session).export_json(session_id, identity.organisation_id, identity.user_id)
    return JSONResponse(payload, headers={"Content-Disposition": f'attachment; filename="guided-{session_id}.json"'})


@router.get("/sessions/{session_id}/export/csv")
async def export_csv(
    session_id: UUID,
    identity: DevelopmentIdentity = Depends(get_development_identity),
    session: AsyncSession = Depends(get_session),
) -> PlainTextResponse:
    payload = await GuidedService(session).export_csv(session_id, identity.organisation_id, identity.user_id)
    return PlainTextResponse(payload, media_type="text/csv", headers={"Content-Disposition": f'attachment; filename="guided-{session_id}.csv"'})