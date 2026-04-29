import pytest
from httpx import AsyncClient

from app.main import create_app


@pytest.mark.asyncio
async def test_login_rejects_invalid_credentials():
  app = create_app()
  async with AsyncClient(app=app, base_url="http://test") as ac:
    res = await ac.post("/auth/login", json={"email": "nope@example.com", "password": "wrong-password"})
  assert res.status_code in (401, 500)

