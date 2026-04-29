import pytest
from httpx import AsyncClient

from app.main import create_app


@pytest.mark.asyncio
async def test_healthz_ok():
  app = create_app()
  async with AsyncClient(app=app, base_url="http://test") as ac:
    res = await ac.get("/healthz")
  assert res.status_code == 200
  assert res.json()["status"] == "ok"

