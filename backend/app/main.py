from fastapi import Depends, FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.router import api_router
from app.api.v1.routes.account_state import router as account_state_router
from app.api.v1.routes.guest import router as guest_router
from app.core.config import get_settings
from app.core.exceptions import (
    ConflictError,
    NotFoundError,
    PermissionDeniedError,
    ServiceUnavailableError,
)
from app.core.database import get_session

settings = get_settings()
app = FastAPI(title="IntQAFlow API", debug=settings.debug)

if settings.app_env == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=(
            r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
            if not settings.cors_origins
            else None
        ),
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
elif settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.exception_handler(NotFoundError)
async def not_found_handler(_: Request, error: NotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"detail": str(error)},
    )


@app.exception_handler(ConflictError)
async def conflict_handler(_: Request, error: ConflictError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={"detail": str(error)},
    )


@app.exception_handler(PermissionDeniedError)
async def permission_denied_handler(
    _: Request,
    error: PermissionDeniedError,
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_403_FORBIDDEN,
        content={"detail": str(error)},
    )


@app.exception_handler(ServiceUnavailableError)
async def service_unavailable_handler(
    _: Request,
    error: ServiceUnavailableError,
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"detail": str(error)},
    )


@app.get("/health", tags=["health"])
async def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.app_env}


@app.get("/ready", tags=["health"])
async def readiness(
    session: AsyncSession = Depends(get_session),
) -> JSONResponse:
    try:
        await session.execute(text("SELECT id FROM organisations LIMIT 0"))
    except SQLAlchemyError:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "not_ready"},
        )
    return JSONResponse(content={"status": "ready"})


app.include_router(api_router, prefix="/api/v1")
app.include_router(account_state_router, prefix="/api/v1")
app.include_router(guest_router, prefix="/api/v1")