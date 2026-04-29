from __future__ import annotations

from typing import Generic, Literal, TypeVar

from pydantic import BaseModel, Field


T = TypeVar("T")


class PaginationMeta(BaseModel):
    page: int = Field(ge=1)
    per_page: int = Field(ge=1, le=200)
    total: int = Field(ge=0)


class ApiError(BaseModel):
    code: str
    message: str


class ApiResponse(BaseModel, Generic[T]):
    success: Literal[True] = True
    data: T


class ApiErrorResponse(BaseModel):
    success: Literal[False] = False
    error: ApiError


class PaginatedResponse(BaseModel, Generic[T]):
    success: Literal[True] = True
    data: list[T]
    pagination: PaginationMeta

