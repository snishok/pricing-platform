from __future__ import annotations

import secrets

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password, verify_password
from app.models.service_api_key import ServiceApiKey
from app.repositories.service_api_key_repository import ServiceApiKeyRepository


class ServiceApiKeyService:
    def __init__(self, repo: ServiceApiKeyRepository | None = None) -> None:
        self._repo = repo or ServiceApiKeyRepository()

    async def create(self, db: AsyncSession, *, name: str, scopes: list[str]) -> tuple[ServiceApiKey, str]:
        # 32 bytes ~= 43 chars base64url; good for copy/paste
        raw = secrets.token_urlsafe(32)
        key_hash = hash_password(raw)
        model = ServiceApiKey(name=name, key_hash=key_hash, scopes=scopes, is_active=True)
        db.add(model)
        await db.commit()
        await db.refresh(model)
        return model, raw

    async def verify(self, db: AsyncSession, *, raw_key: str, required_scope: str) -> ServiceApiKey:
        # we don't know "name" from the key; so we must scan active keys.
        # For a demo, this is acceptable; in production you'd store a key id prefix.
        keys = await self._repo.list_active(db)
        for k in keys:
            if verify_password(raw_key, k.key_hash) and required_scope in (k.scopes or []):
                return k
        raise PermissionError("Invalid API key")

