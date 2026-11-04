from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.dependencies import GuestIdentity, get_guest_identity, require_app_check
from app.api.v1.routes.guest import reject_identity_overrides
from app.core.database import get_session
from app.schemas.suggestion_bank import BankAction, BankCreate, BankScope
from app.services.suggestion_bank import SuggestionBankService

router = APIRouter(
    prefix="/suggestion-bank",
    tags=["Suggestion Bank"],
    dependencies=[Depends(require_app_check), Depends(reject_identity_overrides)],
)


async def service(
    request: Request,
    realm: Literal["organisation", "group"] = "organisation",
    identity: GuestIdentity = Depends(get_guest_identity),
    session: AsyncSession = Depends(get_session),
):
    return await SuggestionBankService(
        session,
        identity,
        realm,
        rate_limit_action=(
            None
            if request.url.path.endswith("/scopes")
            else ("read" if request.method == "GET" else "write")
        ),
    ).initialise()


@router.get("/scopes")
async def scopes(bank=Depends(service)):
    return await bank.scopes()


@router.get("/reviewers")
async def reviewers(
    scope_type: Literal["organisation", "department", "team", "group"],
    scope_id: UUID,
    bank=Depends(service),
):
    return await bank.reviewers(BankScope(scope_type=scope_type, scope_id=scope_id))


@router.get("/nia")
async def nia(
    scope_type: Literal["organisation", "department", "team", "group"],
    scope_id: UUID,
    query: str = Query(default="", max_length=500),
    bank=Depends(service),
):
    return await bank.nia(BankScope(scope_type=scope_type, scope_id=scope_id), query)


@router.get("")
async def suggestions(
    scope_type: Literal["organisation", "department", "team", "group"] | None = None,
    scope_id: UUID | None = None,
    query: str = Query(default="", max_length=100),
    queue: Literal[
        "all", "following", "updates", "unanswered", "overdue", "practices"
    ] = "all",
    offset: int = Query(default=0, ge=0, le=100000),
    limit: int = Query(default=30, ge=1, le=50),
    bank=Depends(service),
):
    return await bank.list(
        scope_type=scope_type,
        scope_id=scope_id,
        query=query,
        queue=queue,
        offset=offset,
        limit=limit,
    )


@router.post("", status_code=201)
async def submit(payload: BankCreate, bank=Depends(service)):
    return await bank.create(payload)


@router.get("/{suggestion_id}")
async def detail(
    suggestion_id: UUID,
    offset: int = Query(default=0, ge=0, le=100000),
    bank=Depends(service),
):
    return await bank.detail(suggestion_id, offset)


@router.post("/{suggestion_id}/actions")
async def action(suggestion_id: UUID, payload: BankAction, bank=Depends(service)):
    return await bank.act(suggestion_id, payload)


@router.post("/{suggestion_id}/seen")
async def seen(suggestion_id: UUID, revision: int = Query(ge=1), bank=Depends(service)):
    return await bank.seen(suggestion_id, revision)
