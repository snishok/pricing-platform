from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class MeResponse(BaseModel):
    id: str
    email: EmailStr
    role: str


class ApiKeyCreateRequest(BaseModel):
    name: str = Field(min_length=3, max_length=128)
    scopes: list[str] = Field(default_factory=lambda: ["upload"])


class ApiKeyCreateResponse(BaseModel):
    id: str
    name: str
    scopes: list[str]
    api_key: str

