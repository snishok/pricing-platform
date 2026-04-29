from __future__ import annotations

from fastapi import APIRouter, Depends
import httpx
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.core.config import settings


router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/readyz")
async def readyz(db: AsyncSession = Depends(get_db)) -> dict[str, str]:
    # DB check
    await db.execute(text("SELECT 1"))

    # Typesense check
    async with httpx.AsyncClient(timeout=2.0) as client:
        res = await client.get(f"{settings.typesense_url()}/health")
        res.raise_for_status()

    return {"status": "ok"}

