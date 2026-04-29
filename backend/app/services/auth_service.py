from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, verify_password
from app.repositories.user_repository import UserRepository


class AuthService:
    def __init__(self, user_repo: UserRepository | None = None) -> None:
        self._user_repo = user_repo or UserRepository()

    async def login(self, db: AsyncSession, *, email: str, password: str) -> str:
        user = await self._user_repo.get_by_email(db, email)
        if not user or not user.is_active:
            raise PermissionError("Invalid credentials")
        if not verify_password(password, user.password_hash):
            raise PermissionError("Invalid credentials")
        return create_access_token(subject=str(user.id), extra={"email": user.email, "role": user.role})

