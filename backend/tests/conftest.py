"""
Fixtures compartilhadas para os testes do backend.

Estratégia:
  - Banco: SQLite in-memory via aiosqlite (novo banco por teste — isolamento total)
  - Redis: FakeRedis (dict em memória, sem TTL real)
  - API: httpx.AsyncClient com ASGITransport (sem servidor HTTP real)
  - Override de dependências: get_db e get_redis são substituídos via
    dependency_overrides e unittest.mock.patch
"""
from unittest.mock import patch

import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Garante que todos os models estão registrados no metadata
import app.models.group     # noqa: F401
import app.models.location  # noqa: F401
import app.models.message   # noqa: F401
import app.models.user      # noqa: F401
from app.core.database import Base, get_db
from main import app

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


# ── Fake Redis ────────────────────────────────────────────────────────────────

class FakeRedis:
    """
    Substituto em memória do Redis para testes.
    Implementa apenas os métodos usados pela aplicação: exists e setex.
    Não implementa TTL real — tokens blacklistados nunca expiram durante o teste.
    """

    def __init__(self) -> None:
        self._store: dict[str, str] = {}

    async def exists(self, key: str) -> int:
        return 1 if key in self._store else 0

    async def setex(self, key: str, ttl: int, value: str) -> None:
        self._store[key] = value


# ── Fixtures de banco de dados ────────────────────────────────────────────────

@pytest.fixture
async def db_session():
    """
    Sessão SQLAlchemy em banco SQLite in-memory.
    Cada teste recebe um banco completamente isolado — criado e destruído
    dentro do escopo da fixture.
    """
    engine = create_async_engine(TEST_DATABASE_URL)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with SessionLocal() as session:
        yield session

    await engine.dispose()


# ── Fixture de Redis ──────────────────────────────────────────────────────────

@pytest.fixture
def fake_redis() -> FakeRedis:
    """Instância fresca do FakeRedis por teste."""
    return FakeRedis()


# ── Fixture do cliente HTTP ───────────────────────────────────────────────────

@pytest.fixture
async def client(db_session: AsyncSession, fake_redis: FakeRedis):
    """
    AsyncClient configurado para chamar o app FastAPI diretamente.

    Overrides aplicados:
      - get_db  → session SQLite in-memory
      - get_redis → FakeRedis (patch nos dois módulos que importam a função)
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

    with (
        patch("app.api.v1.auth.get_redis", new=override_get_redis),
        patch("app.api.dependencies.get_redis", new=override_get_redis),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as ac:
            yield ac

    app.dependency_overrides.clear()
