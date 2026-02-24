from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import engine, Base

# Importa todos os models para que o SQLAlchemy possa configurar os mappers
import app.models.user       # noqa: F401
import app.models.group      # noqa: F401
import app.models.location   # noqa: F401
import app.models.message    # noqa: F401

from app.api.v1 import auth, groups, locations, messages, sos


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await engine.dispose()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# Middlewares de segurança
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)

# Rotas
app.include_router(auth.router,      prefix=f"{settings.API_V1_STR}/auth",      tags=["auth"])
app.include_router(groups.router,    prefix=f"{settings.API_V1_STR}/groups",    tags=["groups"])
app.include_router(locations.router, prefix=f"{settings.API_V1_STR}/locations", tags=["locations"])
app.include_router(messages.router,  prefix=f"{settings.API_V1_STR}/messages",  tags=["messages"])
app.include_router(sos.router,       prefix=f"{settings.API_V1_STR}/sos",       tags=["sos"])


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": settings.VERSION}
