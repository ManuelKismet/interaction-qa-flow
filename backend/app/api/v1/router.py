from fastapi import APIRouter, Depends

from app.api.dependencies import enforce_tenant_scope, get_development_identity, require_app_check
from app.api.v1.routes import (
    auth,
	answers,
	comments,
	departments,
	governance,
	guided,
	organisation_administration,
	questions,
	teams,
)

api_router = APIRouter(
    dependencies=[
        Depends(get_development_identity),
        Depends(require_app_check),
        Depends(enforce_tenant_scope),
    ]
)
api_router.include_router(auth.router)
api_router.include_router(departments.router)
api_router.include_router(questions.router)
api_router.include_router(answers.router)
api_router.include_router(comments.router)
api_router.include_router(governance.router)
api_router.include_router(teams.router)
api_router.include_router(guided.router)
api_router.include_router(organisation_administration.router)