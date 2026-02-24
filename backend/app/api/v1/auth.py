from datetime import datetime, timezone, UTC
from typing import Optional
import uuid

import jwt
from fastapi import APIRouter, Depends, HTTPException, status, Header
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr

from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
    OAUTH_PROVIDERS,
)
from app.core.redis_client import get_redis
from app.api.dependencies import get_current_user
from app.models.user import User

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: str
    name: str
    email: str
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut

class SocialLoginRequest(BaseModel):
    provider: str
    token: str

class RefreshRequest(BaseModel):
    refresh_token: str


# ── Helper ───────────────────────────────────────────────

def _build_login_response(user: User) -> LoginResponse:
    user_id = str(user.id)
    return LoginResponse(
        access_token=create_access_token({"sub": user_id}),
        refresh_token=create_refresh_token({"sub": user_id}),
        user=UserOut(
            id=user_id,
            name=user.name,
            email=user.email,
            avatar_url=user.avatar_url,
        ),
    )


# ── Endpoints ────────────────────────────────────────────

@router.post("/register", response_model=LoginResponse, status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Cadastro com e-mail e senha."""
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="E-mail já cadastrado")

    user = User(
        name=data.name,
        email=data.email,
        hashed_password=hash_password(data.password),
        is_active=True,
        is_verified=False,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    return _build_login_response(user)


@router.post("/login", response_model=LoginResponse)
async def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """Login com e-mail e senha (form-urlencoded: username=email, password)."""
    result = await db.execute(select(User).where(User.email == form.username))
    user = result.scalar_one_or_none()

    if user is None or not user.hashed_password or not verify_password(form.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="E-mail ou senha incorretos")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Conta desativada")

    user.last_seen_at = datetime.now(UTC).replace(tzinfo=None)

    return _build_login_response(user)


@router.post("/social-login", response_model=LoginResponse)
async def social_login(data: SocialLoginRequest, db: AsyncSession = Depends(get_db)):
    """Login/cadastro via provedor OAuth."""
    verify_fn = OAUTH_PROVIDERS.get(data.provider)
    if not verify_fn:
        raise HTTPException(status_code=400, detail=f"Provedor '{data.provider}' não suportado")

    user_info = await verify_fn(data.token)

    result = await db.execute(select(User).where(User.email == user_info["email"]))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            name=user_info["name"],
            email=user_info["email"],
            avatar_url=user_info.get("picture"),
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)

    return _build_login_response(user)


@router.post("/refresh", response_model=LoginResponse)
async def refresh_token(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Renova o access token usando o refresh token."""
    payload = decode_token(data.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Token inválido")

    user_id = payload["sub"]
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Usuário não encontrado")

    return _build_login_response(user)


@router.post("/logout", status_code=204)
async def logout(authorization: str = Header(...)):
    """Invalida o access token adicionando-o à blacklist no Redis."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Header Authorization inválido")

    token = authorization.removeprefix("Bearer ")

    try:
        payload = decode_token(token)
        exp = payload.get("exp", 0)
        now = int(datetime.now(UTC).timestamp())
        ttl = max(exp - now, 1)
    except HTTPException:
        ttl = 3600  # fallback: blacklista por 1h mesmo expirado

    redis = await get_redis()
    await redis.setex(f"bl:{token}", ttl, "1")


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)):
    """Retorna dados do usuário autenticado."""
    return UserOut(
        id=str(current_user.id),
        name=current_user.name,
        email=current_user.email,
        avatar_url=current_user.avatar_url,
    )
