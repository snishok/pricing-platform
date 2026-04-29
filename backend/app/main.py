from __future__ import annotations

import asyncio

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from app.api import auth, health, pricing, upload
from app.core.config import settings
from app.core.db import Base, engine
from app.core.db import SessionLocal
from app.core.logging import configure_logging, logger
from app.core.security import hash_password
from app.core.typesense_client import ensure_pricing_collection, get_typesense_client
from app.models.user import User
from app.repositories.user_repository import UserRepository


async def _retry(coro_factory, *, attempts: int = 30, sleep_s: float = 1.0) -> None:
    last_exc: Exception | None = None
    for _ in range(attempts):
        try:
            await coro_factory()
            return
        except Exception as e:
            last_exc = e
            await asyncio.sleep(sleep_s)
    raise last_exc or RuntimeError("retry failed")


def create_app() -> FastAPI:
    configure_logging(settings.environment)

    limiter = Limiter(key_func=get_remote_address, default_limits=[settings.rate_limit_per_minute])
    app = FastAPI(title=settings.app_name)
    app.state.limiter = limiter
    app.add_middleware(SlowAPIMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(RateLimitExceeded)
    async def ratelimit_handler(_: Request, exc: RateLimitExceeded) -> JSONResponse:
        return JSONResponse(status_code=429, content={"success": False, "error": {"code": "RATE_LIMIT", "message": str(exc)}})

    @app.middleware("http")
    async def error_envelope(request: Request, call_next):
        try:
            return await call_next(request)
        except Exception as e:
            logger.exception("unhandled_error", path=str(request.url.path))
            return JSONResponse(
                status_code=500,
                content={"success": False, "error": {"code": "INTERNAL", "message": "Internal server error"}},
            )

    @app.on_event("startup")
    async def on_startup() -> None:
        async def _db_ready() -> None:
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)

        await _retry(_db_ready, attempts=40, sleep_s=1.0)

        if settings.seed_admin_email and settings.seed_admin_password:
            async with SessionLocal() as session:
                repo = UserRepository()
                email = settings.seed_admin_email.strip().lower()
                password = settings.seed_admin_password.strip()
                existing = await repo.get_by_email(session, email)
                if not existing:
                    session.add(
                        User(
                            email=email,
                            password_hash=hash_password(password),
                            is_active=True,
                        )
                    )
                    await session.commit()
                    logger.info("seed.admin_created", email=email)
                else:
                    logger.info("seed.admin_exists", email=email)

        async def _typesense_ready() -> None:
            client = get_typesense_client()
            await ensure_pricing_collection(client)

        await _retry(_typesense_ready, attempts=40, sleep_s=1.0)

    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(upload.router)
    app.include_router(pricing.router)

    return app


app = create_app()

