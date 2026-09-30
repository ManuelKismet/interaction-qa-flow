from fastapi import APIRouter

from app.api.v1.routes import (
	answers,
	comments,
	departments,
	governance,
	guided,
	organisations,
	questions,
	teams,
)

api_router = APIRouter()
api_router.include_router(organisations.router)
api_router.include_router(departments.router)
api_router.include_router(questions.router)
api_router.include_router(answers.router)
api_router.include_router(comments.router)
api_router.include_router(governance.router)
api_router.include_router(teams.router)
api_router.include_router(guided.router)