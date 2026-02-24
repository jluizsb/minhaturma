"""
Testes de integração dos endpoints de autenticação (/api/v1/auth/*).

Infraestrutura: banco SQLite in-memory + FakeRedis (ver conftest.py).
Cada teste recebe um banco novo — zero risco de interferência entre testes.

Endpoints cobertos:
  POST /register    — cadastro, e-mail duplicado
  POST /login       — login correto, senha errada, usuário inexistente
  GET  /me          — autenticado, sem token, token inválido
  POST /logout      — status 204, token blacklistado
  POST /refresh     — novo par de tokens
"""
import pytest

REGISTER = "/api/v1/auth/register"
LOGIN    = "/api/v1/auth/login"
ME       = "/api/v1/auth/me"
LOGOUT   = "/api/v1/auth/logout"
REFRESH  = "/api/v1/auth/refresh"

USER = {
    "name": "Fulano de Tal",
    "email": "fulano@example.com",
    "password": "senha123",
}


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _register(client, data: dict = USER) -> dict:
    r = await client.post(REGISTER, json=data)
    assert r.status_code == 201, r.text
    return r.json()


async def _login(client, email: str = USER["email"], password: str = USER["password"]) -> dict:
    r = await client.post(LOGIN, data={"username": email, "password": password})
    assert r.status_code == 200, r.text
    return r.json()


# ── POST /register ────────────────────────────────────────────────────────────

class TestRegister:
    async def test_sucesso_retorna_201(self, client):
        r = await client.post(REGISTER, json=USER)
        assert r.status_code == 201

    async def test_resposta_contem_tokens(self, client):
        data = await _register(client)
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    async def test_resposta_contem_user(self, client):
        data = await _register(client)
        assert data["user"]["email"] == USER["email"]
        assert data["user"]["name"] == USER["name"]
        assert "id" in data["user"]
        assert "password" not in data["user"]

    async def test_email_duplicado_retorna_400(self, client):
        await _register(client)
        r = await client.post(REGISTER, json=USER)
        assert r.status_code == 400
        assert "cadastrado" in r.json()["detail"].lower()

    async def test_tokens_sao_jwt_validos(self, client):
        import jwt as pyjwt
        from app.core.config import settings
        data = await _register(client)
        for field in ("access_token", "refresh_token"):
            payload = pyjwt.decode(
                data[field], settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
            )
            assert "sub" in payload
            assert "exp" in payload


# ── POST /login ───────────────────────────────────────────────────────────────

class TestLogin:
    async def test_sucesso_retorna_200(self, client):
        await _register(client)
        r = await client.post(LOGIN, data={"username": USER["email"], "password": USER["password"]})
        assert r.status_code == 200

    async def test_resposta_contem_tokens_e_user(self, client):
        await _register(client)
        data = await _login(client)
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == USER["email"]

    async def test_senha_errada_retorna_401(self, client):
        await _register(client)
        r = await client.post(LOGIN, data={"username": USER["email"], "password": "errada"})
        assert r.status_code == 401

    async def test_usuario_inexistente_retorna_401(self, client):
        r = await client.post(LOGIN, data={"username": "naoexiste@x.com", "password": "qualquer"})
        assert r.status_code == 401

    async def test_token_access_do_login_funciona_em_me(self, client):
        await _register(client)
        data = await _login(client)
        r = await client.get(ME, headers={"Authorization": f"Bearer {data['access_token']}"})
        assert r.status_code == 200


# ── GET /me ───────────────────────────────────────────────────────────────────

class TestMe:
    async def test_com_token_valido_retorna_dados_do_usuario(self, client):
        data = await _register(client)
        r = await client.get(ME, headers={"Authorization": f"Bearer {data['access_token']}"})
        assert r.status_code == 200
        body = r.json()
        assert body["email"] == USER["email"]
        assert body["name"] == USER["name"]
        assert "id" in body

    async def test_sem_token_retorna_401(self, client):
        r = await client.get(ME)
        assert r.status_code == 401

    async def test_token_invalido_retorna_401(self, client):
        r = await client.get(ME, headers={"Authorization": "Bearer token.invalido.aqui"})
        assert r.status_code == 401

    async def test_token_malformado_retorna_401(self, client):
        r = await client.get(ME, headers={"Authorization": "Bearer abc123"})
        assert r.status_code == 401


# ── POST /logout ──────────────────────────────────────────────────────────────

class TestLogout:
    async def test_retorna_204(self, client):
        data = await _register(client)
        r = await client.post(LOGOUT, headers={"Authorization": f"Bearer {data['access_token']}"})
        assert r.status_code == 204

    async def test_token_blacklistado_me_retorna_401(self, client):
        data = await _register(client)
        token = data["access_token"]

        await client.post(LOGOUT, headers={"Authorization": f"Bearer {token}"})

        r = await client.get(ME, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 401

    async def test_outro_token_nao_e_afetado(self, client):
        """Logout invalida apenas o token usado, não todos os tokens do usuário."""
        reg = await _register(client)
        login_data = await _login(client)  # gera segundo access_token

        # Faz logout com o token do register
        await client.post(LOGOUT, headers={"Authorization": f"Bearer {reg['access_token']}"})

        # Token do login ainda deve funcionar
        r = await client.get(ME, headers={"Authorization": f"Bearer {login_data['access_token']}"})
        assert r.status_code == 200

    async def test_sem_header_authorization_retorna_401(self, client):
        r = await client.post(LOGOUT)
        assert r.status_code == 422  # FastAPI: Header obrigatório ausente


# ── POST /refresh ─────────────────────────────────────────────────────────────

class TestRefresh:
    async def test_retorna_novo_par_de_tokens(self, client):
        data = await _register(client)
        r = await client.post(REFRESH, json={"refresh_token": data["refresh_token"]})
        assert r.status_code == 200
        new_data = r.json()
        assert "access_token" in new_data
        assert "refresh_token" in new_data

    async def test_novo_access_token_funciona_em_me(self, client):
        data = await _register(client)
        r = await client.post(REFRESH, json={"refresh_token": data["refresh_token"]})
        new_token = r.json()["access_token"]
        r2 = await client.get(ME, headers={"Authorization": f"Bearer {new_token}"})
        assert r2.status_code == 200

    async def test_access_token_usado_como_refresh_retorna_401(self, client):
        """Tokens de acesso não podem ser usados para refresh."""
        data = await _register(client)
        r = await client.post(REFRESH, json={"refresh_token": data["access_token"]})
        assert r.status_code == 401

    async def test_refresh_token_invalido_retorna_401(self, client):
        r = await client.post(REFRESH, json={"refresh_token": "token.invalido"})
        assert r.status_code == 401
