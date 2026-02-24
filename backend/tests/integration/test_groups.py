"""
Testes de integração dos endpoints de grupos (/api/v1/groups/*).

Endpoints cobertos:
  POST /groups/        — criar grupo
  GET  /groups/        — listar grupos
  POST /groups/join    — entrar por código de convite
  DELETE /groups/{id}/leave — sair do grupo
"""
import pytest

REGISTER = "/api/v1/auth/register"
LOGIN    = "/api/v1/auth/login"
GROUPS   = "/api/v1/groups/"
JOIN     = "/api/v1/groups/join"

USER_A = {"name": "Alice", "email": "alice@example.com", "password": "senha123"}
USER_B = {"name": "Bob",   "email": "bob@example.com",   "password": "senha456"}


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _register_and_token(client, data: dict) -> str:
    r = await client.post(REGISTER, json=data)
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


async def _create_group(client, token: str, name: str = "Família") -> dict:
    r = await client.post(
        GROUPS,
        json={"name": name, "description": "Grupo de teste"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 201, r.text
    return r.json()


# ── POST /groups/ ─────────────────────────────────────────────────────────────

class TestCreateGroup:
    async def test_criar_grupo_retorna_201(self, client):
        token = await _register_and_token(client, USER_A)
        r = await client.post(
            GROUPS,
            json={"name": "Turma do João"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert r.status_code == 201

    async def test_grupo_tem_invite_code(self, client):
        token = await _register_and_token(client, USER_A)
        group = await _create_group(client, token)
        assert "invite_code" in group
        assert len(group["invite_code"]) > 0

    async def test_criador_e_admin(self, client):
        token = await _register_and_token(client, USER_A)
        group = await _create_group(client, token)
        assert group["member_count"] == 1
        assert group["members"][0]["role"] == "admin"

    async def test_sem_auth_retorna_401(self, client):
        r = await client.post(GROUPS, json={"name": "X"})
        assert r.status_code == 401


# ── GET /groups/ ──────────────────────────────────────────────────────────────

class TestListGroups:
    async def test_listar_retorna_grupos_do_usuario(self, client):
        token = await _register_and_token(client, USER_A)
        await _create_group(client, token, "Grupo 1")
        await _create_group(client, token, "Grupo 2")

        r = await client.get(GROUPS, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        assert len(r.json()) == 2

    async def test_usuario_sem_grupo_retorna_lista_vazia(self, client):
        token = await _register_and_token(client, USER_A)
        r = await client.get(GROUPS, headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        assert r.json() == []


# ── POST /groups/join ─────────────────────────────────────────────────────────

class TestJoinGroup:
    async def test_entrar_por_invite_code(self, client):
        token_a = await _register_and_token(client, USER_A)
        token_b = await _register_and_token(client, USER_B)
        group = await _create_group(client, token_a)

        r = await client.post(
            JOIN,
            json={"invite_code": group["invite_code"]},
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert r.status_code == 200
        assert r.json()["member_count"] == 2

    async def test_codigo_invalido_retorna_404(self, client):
        token = await _register_and_token(client, USER_A)
        r = await client.post(
            JOIN,
            json={"invite_code": "INVALIDO"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert r.status_code == 404

    async def test_entrar_duas_vezes_retorna_400(self, client):
        token = await _register_and_token(client, USER_A)
        group = await _create_group(client, token)

        r = await client.post(
            JOIN,
            json={"invite_code": group["invite_code"]},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert r.status_code == 400


# ── DELETE /groups/{id}/leave ─────────────────────────────────────────────────

class TestLeaveGroup:
    async def test_sair_do_grupo_retorna_204(self, client):
        token = await _register_and_token(client, USER_A)
        group = await _create_group(client, token)

        r = await client.delete(
            f"/api/v1/groups/{group['id']}/leave",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert r.status_code == 204

    async def test_nao_membro_retorna_404(self, client):
        token_a = await _register_and_token(client, USER_A)
        token_b = await _register_and_token(client, USER_B)
        group = await _create_group(client, token_a)

        r = await client.delete(
            f"/api/v1/groups/{group['id']}/leave",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        assert r.status_code == 404
