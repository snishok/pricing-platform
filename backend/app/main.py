from __future__ import annotations

import asyncio

from datetime import date

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address
from sqlalchemy import text

from app.api import auth, health, pricing, upload
from app.core.config import settings
from app.core.db import Base, engine
from app.core.db import SessionLocal
from app.core.logging import configure_logging, logger
from app.core.security import hash_password
from app.core.roles import UserRole
from app.core.typesense_client import ensure_pricing_collection, get_typesense_client
from app.core.partitioning import convert_pricing_records_to_partitioned, ensure_monthly_partitions
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

    limiter = Limiter(
        key_func=get_remote_address,
        default_limits=[settings.rate_limit_per_minute],
        enabled=settings.rate_limit_enabled,
        storage_uri=settings.rate_limit_storage_uri,
    )
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
        except Exception:
            logger.exception("unhandled_error", path=str(request.url.path))
            return JSONResponse(
                status_code=500,
                content={"success": False, "error": {"code": "INTERNAL", "message": "Internal server error"}},
            )

    @app.on_event("startup")
    async def on_startup() -> None:
        async def _db_ready() -> None:
            async with engine.begin() as conn:
                # Extensions used for scalable fallback search
                await conn.execute(text("CREATE EXTENSION IF NOT EXISTS pg_trgm"))

                await conn.run_sync(Base.metadata.create_all)
                # Lightweight "migration" for local dev: older volumes may miss columns.
                # create_all won't add missing columns, so patch common drift safely.
                await conn.execute(
                    text(
                        """
                        ALTER TABLE IF EXISTS users
                        ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'viewer'
                        """
                    )
                )
                # Backfill + add new columns for pricing_records
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) NOT NULL DEFAULT 'XX'"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) NOT NULL DEFAULT 'USD'"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS tax_inclusive BOOLEAN NOT NULL DEFAULT TRUE"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS feed_id UUID NULL"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS source_line INTEGER NULL"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS updated_by_user_id UUID NULL"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS updated_source VARCHAR(32) NOT NULL DEFAULT 'ingest'"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_records ADD COLUMN IF NOT EXISTS update_reason TEXT NULL"))

                # Upserts rely on a unique index for ON CONFLICT (country_code, store_id, sku, date).
                # Existing volumes may contain duplicates; dedupe first (keep newest record per key).
                await conn.execute(
                    text(
                        """
                        WITH ranked AS (
                          SELECT
                            ctid,
                            ROW_NUMBER() OVER (
                              PARTITION BY country_code, store_id, sku, date
                              ORDER BY updated_at DESC, created_at DESC, id DESC
                            ) AS rn
                          FROM pricing_records
                        )
                        DELETE FROM pricing_records
                        WHERE ctid IN (SELECT ctid FROM ranked WHERE rn > 1)
                        """
                    )
                )
                await conn.execute(
                    text(
                        """
                        CREATE UNIQUE INDEX IF NOT EXISTS uq_pricing_records_country_store_sku_date_idx
                        ON pricing_records (country_code, store_id, sku, date)
                        """
                    )
                )

                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_pricing_records_country_code ON pricing_records(country_code)"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_pricing_records_currency_code ON pricing_records(currency_code)"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_pricing_records_feed_id ON pricing_records(feed_id)"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_pricing_records_updated_by_user_id ON pricing_records(updated_by_user_id)"))

                # Scalable fallback search for product_name ILIKE '%...%'
                await conn.execute(
                    text(
                        """
                        CREATE INDEX IF NOT EXISTS gin_pricing_records_product_name_trgm
                        ON pricing_records USING GIN (product_name gin_trgm_ops)
                        """
                    )
                )
                # Helps large append-only time-range scans (works well with partitioning later too)
                await conn.execute(text("CREATE INDEX IF NOT EXISTS brin_pricing_records_date ON pricing_records USING BRIN (date)"))

                if settings.enable_pricing_partitioning:
                    await convert_pricing_records_to_partitioned(conn)
                    await ensure_monthly_partitions(
                        conn,
                        table_name="pricing_records",
                        partition_column="date",
                        start_month=date.today().replace(day=1),
                        months_backfill=settings.pricing_partition_months_backfill,
                        months_ahead=settings.pricing_partition_months_ahead,
                    )

                # Audit table drift patches for older volumes
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_record_audits ADD COLUMN IF NOT EXISTS feed_id UUID NULL"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_record_audits ADD COLUMN IF NOT EXISTS source VARCHAR(32) NOT NULL DEFAULT 'manual'"))
                await conn.execute(text("ALTER TABLE IF EXISTS pricing_record_audits ADD COLUMN IF NOT EXISTS reason TEXT NULL"))
                await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_pricing_record_audits_feed_id ON pricing_record_audits(feed_id)"))

                # Enforce non-negative price at DB level (if missing)
                await conn.execute(
                    text(
                        """
                        DO $$
                        BEGIN
                          IF NOT EXISTS (
                            SELECT 1 FROM pg_constraint WHERE conname = 'ck_pricing_records_price_non_negative'
                          ) THEN
                            ALTER TABLE pricing_records
                            ADD CONSTRAINT ck_pricing_records_price_non_negative CHECK (price >= 0);
                          END IF;
                        END $$;
                        """
                    )
                )

        await _retry(_db_ready, attempts=40, sleep_s=1.0)

        async with SessionLocal() as session:
            repo = UserRepository()

            async def _seed_user(*, email: str | None, password: str | None, role: UserRole) -> None:
                if not email or not password:
                    return
                e = email.strip().lower()
                p = password.strip()
                existing = await repo.get_by_email(session, e)
                if not existing:
                    session.add(
                        User(
                            email=e,
                            password_hash=hash_password(p),
                            is_active=True,
                            role=role.value,
                        )
                    )
                    await session.commit()
                    logger.info("seed.user_created", email=e, role=role.value)
                else:
                    # if the role changed (e.g. you reconfigured env vars), keep it updated for demos
                    if existing.role != role.value:
                        existing.role = role.value
                        await session.commit()
                        logger.info("seed.user_role_updated", email=e, role=role.value)
                    else:
                        logger.info("seed.user_exists", email=e, role=role.value)

            await _seed_user(email=settings.seed_admin_email, password=settings.seed_admin_password, role=UserRole.admin)
            await _seed_user(email=settings.seed_viewer_email, password=settings.seed_viewer_password, role=UserRole.viewer)
            await _seed_user(email=settings.seed_editor_email, password=settings.seed_editor_password, role=UserRole.editor)
            await _seed_user(email=settings.seed_uploader_email, password=settings.seed_uploader_password, role=UserRole.uploader)

        async def _typesense_ready() -> None:
            client = get_typesense_client()
            await ensure_pricing_collection(client)

        if settings.environment != "test":
            await _retry(_typesense_ready, attempts=40, sleep_s=1.0)

    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(upload.router)
    app.include_router(pricing.router)

    return app


app = create_app()

