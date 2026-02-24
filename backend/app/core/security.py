from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import httpx
import jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ─────────────────────────────────────────────
# Senhas
# ─────────────────────────────────────────────

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ─────────────────────────────────────────────
# JWT Tokens
# ─────────────────────────────────────────────

def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_refresh_token(data: Dict[str, Any]) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def decode_token(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expirado")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")


# ─────────────────────────────────────────────
# OAuth Providers — Verificação de tokens externos
# ─────────────────────────────────────────────

async def verify_google_token(token: str) -> Dict[str, Any]:
    """Verifica token ID do Google e retorna dados do usuário."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": token}
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Token Google inválido")
    data = resp.json()
    if data.get("aud") != settings.GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=401, detail="Token Google não pertence a este app")
    return {
        "provider": "google",
        "provider_id": data["sub"],
        "email": data["email"],
        "name": data.get("name", ""),
        "picture": data.get("picture", ""),
    }

async def verify_facebook_token(token: str) -> Dict[str, Any]:
    """Verifica token do Facebook e retorna dados do usuário."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://graph.facebook.com/me",
            params={"access_token": token, "fields": "id,name,email,picture"}
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Token Facebook inválido")
    data = resp.json()
    return {
        "provider": "facebook",
        "provider_id": data["id"],
        "email": data.get("email", ""),
        "name": data.get("name", ""),
        "picture": data.get("picture", {}).get("data", {}).get("url", ""),
    }

async def verify_apple_token(token: str) -> Dict[str, Any]:
    """Verifica token Sign in with Apple."""
    # Apple usa JWT assinado — decodifica sem verificar assinatura aqui
    # Em produção, validar com chave pública da Apple
    try:
        payload = jwt.decode(token, options={"verify_signature": False})
        return {
            "provider": "apple",
            "provider_id": payload["sub"],
            "email": payload.get("email", ""),
            "name": "",
            "picture": "",
        }
    except Exception:
        raise HTTPException(status_code=401, detail="Token Apple inválido")

async def verify_microsoft_token(token: str) -> Dict[str, Any]:
    """Verifica token Microsoft/Azure AD."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://graph.microsoft.com/v1.0/me",
            headers={"Authorization": f"Bearer {token}"}
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Token Microsoft inválido")
    data = resp.json()
    return {
        "provider": "microsoft",
        "provider_id": data["id"],
        "email": data.get("mail") or data.get("userPrincipalName", ""),
        "name": data.get("displayName", ""),
        "picture": "",
    }

# Mapa de provedores
OAUTH_PROVIDERS = {
    "google":    verify_google_token,
    "facebook":  verify_facebook_token,
    "apple":     verify_apple_token,
    "microsoft": verify_microsoft_token,
}
