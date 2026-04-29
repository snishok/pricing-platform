from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import AuthContext, get_db, require_auth, require_roles
from app.core.roles import UserRole
from app.schemas.auth import ApiKeyCreateRequest, ApiKeyCreateResponse, LoginRequest, MeResponse, TokenResponse
from app.services.auth_service import AuthService
from app.services.service_api_key_service import ServiceApiKeyService


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    try:
        token = await AuthService().login(db, email=str(payload.email).lower(), password=payload.password)
        return TokenResponse(access_token=token)
    except PermissionError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")


@router.get("/me")
async def me(ctx: AuthContext = Depends(require_auth)) -> MeResponse:
    return MeResponse(id=str(ctx.user_id), email=ctx.email, role=ctx.role)


@router.post("/api-keys", response_model=ApiKeyCreateResponse)
async def create_api_key(
    payload: ApiKeyCreateRequest,
    db: AsyncSession = Depends(get_db),
    _: AuthContext = Depends(require_roles({UserRole.admin})),
) -> ApiKeyCreateResponse:
    model, raw = await ServiceApiKeyService().create(db, name=payload.name, scopes=payload.scopes)
    return ApiKeyCreateResponse(id=str(model.id), name=model.name, scopes=model.scopes or [], api_key=raw)

