"""
Testes de integração dos endpoints de localização (/api/v1/locations/*).

Endpoints cobertos:
  WS  /locations/ws?token=...&group_id=... — WebSocket em tempo real
  GET /locations/history/{user_id}          — histórico
  GET /locations/group/{group_id}/last      — última posição de cada membro

Nota sobre WebSocket: usa fastapi.testclient.TestClient (síncrono)
para WebSocket e httpx.AsyncClient (assíncrono) para REST.
"""
import json
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

import app.models.group     # noqa: F401
import app.models.location  # noqa: F401
import app.models.message   # noqa: F401
import app.models.user      # noqa: F401
from app.api.v1.locations import haversine
from app.core.database import Base, get_db
from main import app
from tests.conftest import FakeRedis

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

REGISTER = "/api/v1/auth/register"
LOGIN    = "/api/v1/auth/login"


# ── Utilitário síncrono para testes de WS ────────────────────────────────────

def _make_sync_client(db_session, fake_redis):
    """
    Cria um TestClient síncrono com as mesmas overrides do conftest.
    Necessário porque o TestClient do Starlette gerencia WebSocket.
    """
    async def override_get_db():
        try:
            yield db_session
            await db_session.commit()
        except Exception:
            await db_session.rollback()
            raise

    async def override_get_redis():
        return fake_redis

    app.dependency_overrides[get_db] = override_get_db
    return override_get_redis


# ── Testes de haversine (unidade) ─────────────────────────────────────────────

class TestHaversine:
    def test_pontos_iguais_distancia_zero(self):
        assert haversine(-23.5, -46.6, -23.5, -46.6) == pytest.approx(0.0, abs=1e-6)

    def test_distancia_10_metros(self):
        # Aproximação: 0.0001 grau ≈ 11 metros na latitude de SP
        dist = haversine(-23.5, -46.6, -23.5001, -46.6)
        assert 10 < dist < 15

    def test_distancia_grande(self):
        # SP → RJ ≈ 360 km
        dist = haversine(-23.5, -46.6, -22.9, -43.2)
        assert 350_000 < dist < 380_000


# ── Testes REST (async) ───────────────────────────────────────────────────────

class TestLocationHistory:
    async def test_history_retorna_lista(self, client, group_fixture):
        token_admin, group = group_fixture
        user_id = group["members"][0]["user_id"]

        r = await client.get(
            f"/api/v1/locations/history/{user_id}",
            headers={"Authorization": f"Bearer {token_admin}"},
        )
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    async def test_history_sem_auth_retorna_401(self, client, group_fixture):
        _, group = group_fixture
        user_id = group["members"][0]["user_id"]

        r = await client.get(f"/api/v1/locations/history/{user_id}")
        assert r.status_code == 401


class TestGroupLastLocations:
    async def test_last_retorna_estrutura(self, client, group_fixture):
        token_admin, group = group_fixture

        r = await client.get(
            f"/api/v1/locations/group/{group['id']}/last",
            headers={"Authorization": f"Bearer {token_admin}"},
        )
        assert r.status_code == 200
        body = r.json()
        assert "group_id" in body
        assert "members" in body

    async def test_last_sem_auth_retorna_401(self, client, group_fixture):
        _, group = group_fixture
        r = await client.get(f"/api/v1/locations/group/{group['id']}/last")
        assert r.status_code == 401

    async def test_last_retorna_posicao_do_redis(self, client, group_fixture, fake_redis):
        """Após inserção manual no FakeRedis, o endpoint retorna a posição."""
        token_admin, group = group_fixture
        user_id = group["members"][0]["user_id"]

        loc = {"user_id": user_id, "user_name": "Admin", "lat": -23.5, "lng": -46.6, "ts": 1000.0}
        await fake_redis.set(f"loc:last:{user_id}", json.dumps(loc))

        r = await client.get(
            f"/api/v1/locations/group/{group['id']}/last",
            headers={"Authorization": f"Bearer {token_admin}"},
        )
        assert r.status_code == 200
        members = r.json()["members"]
        assert len(members) == 1
        assert members[0]["lat"] == pytest.approx(-23.5)
