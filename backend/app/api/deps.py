from __future__ import annotations

import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db_session
from app.core.roles import UPLOAD_ROLES, UserRole
from app.core.security import decode_token
from app.services.service_api_key_service import ServiceApiKeyService


security = HTTPBearer(auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

_DETAIL_INVALID_ROLE = "Invalid role"


async def get_db(db: AsyncSession = Depends(get_db_session)) -> AsyncSession:
    return db


class AuthContext:
    def __init__(self, *, user_id: uuid.UUID, email: str | None, role: str | None) -> None:
        self.user_id = user_id
        self.email = email or ""
        self.role = role or UserRole.viewer.value


async def require_auth(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> AuthContext:
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    try:
        payload = decode_token(credentials.credentials)
        sub = payload.get("sub")
        user_id = uuid.UUID(sub)
        return AuthContext(user_id=user_id, email=payload.get("email"), role=payload.get("role"))
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid bearer token") from exc


async def require_user_id(ctx: AuthContext = Depends(require_auth)) -> uuid.UUID:
    return ctx.user_id


def require_roles(allowed: set[UserRole]):
    async def _dep(ctx: AuthContext = Depends(require_auth)) -> AuthContext:
        try:
            role = UserRole(ctx.role)
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_DETAIL_INVALID_ROLE) from exc
        if role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return ctx

    return _dep


class UploadActor:
    def __init__(self, *, user_id: uuid.UUID | None, api_key_id: uuid.UUID | None) -> None:
        self.user_id = user_id
        self.api_key_id = api_key_id


async def require_upload_actor(
    db: AsyncSession = Depends(get_db_session),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    api_key: str | None = Depends(api_key_header),
) -> UploadActor:
    if credentials is not None:
        ctx = await require_auth(credentials)
        try:
            role = UserRole(ctx.role)
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_DETAIL_INVALID_ROLE) from exc
        if role not in UPLOAD_ROLES:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return UploadActor(user_id=ctx.user_id, api_key_id=None)

    if api_key:
        try:
            key = await ServiceApiKeyService().verify(db, raw_key=api_key, required_scope="upload")
            return UploadActor(user_id=None, api_key_id=key.id)
        except PermissionError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key") from exc

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing credentials")

