"""
Testes unitários de app/core/security.py

Coberturas:
  - hash_password: formato bcrypt, idempotência
  - verify_password: senha correta, senha errada, senha vazia
  - create_access_token: payload correto, tipo "access"
  - create_refresh_token: tipo "refresh"
  - decode_token: payload retornado, token expirado (401), token inválido (401)

Nenhuma dependência externa (banco/Redis) necessária.
"""
from datetime import timedelta

import jwt
import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)


# ── hash_password ─────────────────────────────────────────────────────────────

class TestHashPassword:
    def test_retorna_string_nao_vazia(self):
        result = hash_password("minhasenha")
        assert isinstance(result, str)
        assert len(result) > 0

    def test_hash_tem_prefixo_bcrypt(self):
        result = hash_password("minhasenha")
        assert result.startswith("$2b$")

    def test_hash_diferente_da_senha_original(self):
        senha = "segredo"
        assert hash_password(senha) != senha

    def test_dois_hashes_da_mesma_senha_sao_diferentes(self):
        """bcrypt usa salt aleatório — dois hashes nunca são iguais."""
        h1 = hash_password("igual")
        h2 = hash_password("igual")
        assert h1 != h2


# ── verify_password ───────────────────────────────────────────────────────────

class TestVerifyPassword:
    def test_senha_correta_retorna_true(self):
        hashed = hash_password("senha123")
        assert verify_password("senha123", hashed) is True

    def test_senha_errada_retorna_false(self):
        hashed = hash_password("senha123")
        assert verify_password("errada", hashed) is False

    def test_senha_vazia_retorna_false(self):
        hashed = hash_password("senha123")
        assert verify_password("", hashed) is False

    def test_case_sensitive(self):
        hashed = hash_password("Senha123")
        assert verify_password("senha123", hashed) is False
        assert verify_password("Senha123", hashed) is True


# ── create_access_token ───────────────────────────────────────────────────────

class TestCreateAccessToken:
    def test_token_contem_sub(self):
        token = create_access_token({"sub": "user-abc"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["sub"] == "user-abc"

    def test_token_tem_tipo_access(self):
        token = create_access_token({"sub": "x"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["type"] == "access"

    def test_token_contem_campo_exp(self):
        token = create_access_token({"sub": "x"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert "exp" in payload

    def test_dados_customizados_preservados(self):
        token = create_access_token({"sub": "x", "role": "admin"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["role"] == "admin"

    def test_expires_delta_customizado(self):
        import time
        token = create_access_token({"sub": "x"}, expires_delta=timedelta(hours=2))
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        # Expiração deve ser ~2h a partir de agora (com margem de 10s)
        assert payload["exp"] > int(time.time()) + 7190


# ── create_refresh_token ──────────────────────────────────────────────────────

class TestCreateRefreshToken:
    def test_token_tem_tipo_refresh(self):
        token = create_refresh_token({"sub": "user-abc"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["type"] == "refresh"

    def test_token_contem_sub(self):
        token = create_refresh_token({"sub": "user-abc"})
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["sub"] == "user-abc"

    def test_refresh_e_access_sao_diferentes(self):
        access = create_access_token({"sub": "u"})
        refresh = create_refresh_token({"sub": "u"})
        assert access != refresh


# ── decode_token ──────────────────────────────────────────────────────────────

class TestDecodeToken:
    def test_decodifica_payload_correto(self):
        token = create_access_token({"sub": "abc", "custom": "valor"})
        payload = decode_token(token)
        assert payload["sub"] == "abc"
        assert payload["custom"] == "valor"

    def test_token_expirado_lanca_401(self):
        token = create_access_token({"sub": "u"}, expires_delta=timedelta(seconds=-1))
        with pytest.raises(HTTPException) as exc:
            decode_token(token)
        assert exc.value.status_code == 401

    def test_token_invalido_lanca_401(self):
        with pytest.raises(HTTPException) as exc:
            decode_token("header.payload.assinatura_invalida")
        assert exc.value.status_code == 401

    def test_token_completamente_malformado_lanca_401(self):
        with pytest.raises(HTTPException) as exc:
            decode_token("isto_nao_e_um_jwt")
        assert exc.value.status_code == 401
