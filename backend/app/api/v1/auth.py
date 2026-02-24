from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, EmailStr
from typing import Optional

from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
    OAUTH_PROVIDERS,
)

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


# ── Schemas ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class SocialLoginRequest(BaseModel):
    provider: str          # google | facebook | apple | microsoft | aws
    token: str             # token retornado pelo SDK do provedor no app

class RefreshRequest(BaseModel):
    refresh_token: str


# ── Endpoints ────────────────────────────────────────────

@router.post("/register", status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Cadastro com e-mail e senha."""
    # TODO: verificar se e-mail já existe
    # TODO: criar usuário no banco
    # TODO: enviar e-mail de verificação via AWS SES
    return {"message": "Usuário criado. Verifique seu e-mail."}


@router.post("/login", response_model=LoginResponse)
async def login(form: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    """Login com e-mail e senha."""
    # TODO: buscar usuário, verificar senha
    user_id = "placeholder-uuid"
    access_token  = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})
    return LoginResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/social-login", response_model=LoginResponse)
async def social_login(data: SocialLoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Login/cadastro via provedor OAuth:
    - google | facebook | apple | microsoft
    O app mobile faz o login no SDK do provedor e envia o token aqui.
    """
    verify_fn = OAUTH_PROVIDERS.get(data.provider)
    if not verify_fn:
        raise HTTPException(status_code=400, detail=f"Provedor '{data.provider}' não suportado")

    user_info = await verify_fn(data.token)

    # TODO: buscar ou criar usuário no banco com base em user_info
    # TODO: vincular provider_id ao usuário existente se e-mail já cadastrado
    user_id = "placeholder-uuid"

    access_token  = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})
    return LoginResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=LoginResponse)
async def refresh_token(data: RefreshRequest):
    """Renova o access token usando o refresh token."""
    payload = decode_token(data.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Token inválido")
    user_id = payload["sub"]
    access_token  = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})
    return LoginResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/logout")
async def logout():
    """Invalida o token (client deve apagar o token local)."""
    # TODO: adicionar token à blacklist no Redis
    return {"message": "Logout realizado com sucesso"}
