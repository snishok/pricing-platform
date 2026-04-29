from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.service_api_key import ServiceApiKey


class ServiceApiKeyRepository:
    async def get_by_name(self, db: AsyncSession, name: str) -> ServiceApiKey | None:
        res = await db.execute(select(ServiceApiKey).where(ServiceApiKey.name == name))
        return res.scalar_one_or_none()

    async def get_by_id(self, db: AsyncSession, api_key_id) -> ServiceApiKey | None:
        res = await db.execute(select(ServiceApiKey).where(ServiceApiKey.id == api_key_id))
        return res.scalar_one_or_none()

    async def list_active(self, db: AsyncSession) -> list[ServiceApiKey]:
        res = await db.execute(select(ServiceApiKey).where(ServiceApiKey.is_active.is_(True)).order_by(ServiceApiKey.created_at.desc()))
        return list(res.scalars().all())

