# Backend — Documentação

Aplicação FastAPI com SQLAlchemy assíncrono, PostgreSQL e Redis.

## Estrutura de arquivos

```
backend/
├── main.py                    # Ponto de entrada: cria o app, registra routers
├── requirements.txt           # Dependências Python
├── pytest.ini                 # Configuração do pytest
├── .env                       # Variáveis de ambiente (não comitado)
├── .env.example               # Template das variáveis
├── docker-compose.yml         # PostgreSQL 16 + Redis 7
│
└── app/
    ├── core/
    │   ├── config.py          # Pydantic Settings (lê o .env)
    │   ├── database.py        # Engine + SessionLocal assíncronos
    │   ├── redis_client.py    # Pool de conexão Redis (singleton)
    │   └── security.py        # JWT + bcrypt + verificadores OAuth
    │
    ├── api/
    │   ├── dependencies.py    # Dependency get_current_user (JWT + blacklist)
    │   └── v1/
    │       ├── auth.py        # POST register|login|logout|refresh; GET me
    │       ├── groups.py      # CRUD grupos (esqueleto)
    │       ├── locations.py   # WebSocket + histórico (esqueleto)
    │       ├── messages.py    # Chat + upload mídia (esqueleto)
    │       └── sos.py         # SOS (esqueleto)
    │
    └── models/
        ├── user.py            # User (SQLAlchemy ORM)
        ├── group.py           # Group, GroupMember
        ├── location.py        # Location, Geofence
        └── message.py         # Message, SOSEvent
```

## Ponto de entrada — `main.py`

```python
# Importações explícitas dos modelos são necessárias para o SQLAlchemy
# configurar o mapper antes que qualquer query seja executada.
import app.models.user       # noqa: F401
import app.models.group      # noqa: F401
import app.models.location   # noqa: F401
import app.models.message    # noqa: F401

app = FastAPI(title="MinhaTurma API", version="1.0.0")
app.include_router(auth_router,      prefix="/api/v1/auth")
app.include_router(groups_router,    prefix="/api/v1/groups")
app.include_router(locations_router, prefix="/api/v1/locations")
app.include_router(messages_router,  prefix="/api/v1/messages")
app.include_router(sos_router,       prefix="/api/v1/sos")
```

> **Por que importar os modelos explicitamente?**
> O SQLAlchemy lazy-load os mappers. Se o modelo `GroupMember` não for importado antes do primeiro acesso ao modelo `User` (que possui relacionamento com `GroupMember`), o mapper levanta `InvalidRequestError`. A importação explícita no `main.py` garante que todos os modelos são registrados antes de qualquer request.

## Módulo `core/`

### `config.py` — configurações via `.env`

| Variável | Padrão | Descrição |
|---|---|---|
| `DATABASE_URL` | — | URL asyncpg do PostgreSQL |
| `REDIS_URL` | — | `redis://:senha@host:port` |
| `SECRET_KEY` | — | Chave de assinatura JWT (≥ 32 chars) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | 60 | Expiração do access token |
| `REFRESH_TOKEN_EXPIRE_DAYS` | 30 | Expiração do refresh token |

### `database.py` — engine assíncrono

```python
engine = create_async_engine(settings.DATABASE_URL, echo=False)
async_session_maker = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with async_session_maker() as session:
        yield session
```

### `redis_client.py` — pool singleton

```python
_redis_pool: aioredis.Redis | None = None

async def get_redis() -> aioredis.Redis:
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis_pool
```

> O pool é criado uma única vez e reutilizado em todas as requests. `decode_responses=True` retorna strings Python em vez de bytes.

### `security.py` — JWT e bcrypt

#### Hash de senhas

```python
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())
```

#### Criação de tokens

```python
def create_access_token(user_id: str) -> str:
    expire = datetime.now(UTC).replace(tzinfo=None) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": user_id, "type": "access", "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(UTC).replace(tzinfo=None) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": user_id, "type": "refresh", "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")
```

#### Decodificação e validação

```python
def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido")
```

## Camada de segurança — `dependencies.py`

```python
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    payload = decode_token(token)                          # valida JWT

    redis = await get_redis()
    if await redis.exists(f"bl:{token}"):                  # verifica blacklist
        raise HTTPException(status_code=401, detail="Token revogado")

    user_id = payload.get("sub")
    result = await db.execute(
        select(User).where(User.id == uuid.UUID(user_id))  # UUID object, não string
    )
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="Usuário não encontrado")

    return user
```

> **Atenção ao UUID:** a coluna `User.id` é `UUID(as_uuid=True)` do SQLAlchemy. Ao filtrar por string (vinda do JWT), é obrigatório converter com `uuid.UUID(user_id)`. Caso contrário, o SQLAlchemy tenta chamar `.hex` na string e lança `AttributeError` (visto em produção e nos testes com SQLite).

## Endpoints de autenticação — `api/v1/auth.py`

### Schemas de resposta

```python
class UserOut(BaseModel):
    id: str
    name: str
    email: str
    avatar_url: str | None

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut
```

### Helper compartilhado

```python
def _build_login_response(user: User) -> LoginResponse:
    return LoginResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserOut(id=str(user.id), name=user.name, email=user.email, avatar_url=user.avatar_url),
    )
```

### `POST /api/v1/auth/register`

| Campo | Tipo | Descrição |
|---|---|---|
| `name` | string | Nome completo |
| `email` | string | E-mail único |
| `password` | string | Senha em texto claro (hash feito aqui) |

**Fluxo:**
1. Verifica se e-mail já existe → `400 Email already registered`
2. Cria `User` com `hash_password(password)`
3. `db.flush()` + `db.refresh(user)` para obter o UUID gerado
4. Retorna `LoginResponse` com tokens + dados do usuário

### `POST /api/v1/auth/login`

Recebe `application/x-www-form-urlencoded` (compatível com `OAuth2PasswordRequestForm`):

| Campo | Tipo |
|---|---|
| `username` | string (e-mail) |
| `password` | string |

**Fluxo:**
1. Busca usuário por e-mail
2. `verify_password(password, user.hashed_password)` → `401` se falhar
3. Atualiza `last_seen_at = datetime.now(UTC).replace(tzinfo=None)`
4. Retorna `LoginResponse`

### `POST /api/v1/auth/logout`

Header: `Authorization: Bearer <access_token>`

**Fluxo:**
1. Decodifica o token para obter `exp`
2. Calcula TTL restante: `exp - agora`
3. `redis.setex(f"bl:{token}", ttl, "1")`
4. Retorna `204 No Content`

### `POST /api/v1/auth/refresh`

Body JSON: `{"refresh_token": "..."}`

**Fluxo:**
1. Decodifica e valida o refresh token (`type == "refresh"`)
2. Busca o usuário no banco (garante que ainda existe e está ativo)
3. Emite novo par de tokens

### `GET /api/v1/auth/me`

Header: `Authorization: Bearer <access_token>`

Protegido por `Depends(get_current_user)`. Retorna `UserOut` do usuário autenticado.

## Modelos SQLAlchemy — `models/`

### `user.py`

```python
class User(Base):
    __tablename__ = "users"
    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email           = Column(String(255), unique=True, index=True, nullable=False)
    name            = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=True)  # None para logins OAuth
    is_active       = Column(Boolean, default=True)
    is_verified     = Column(Boolean, default=False)
    last_seen_at    = Column(DateTime, nullable=True)
    # + google_id, facebook_id, apple_id, microsoft_id, aws_cognito_id
    # + relationships: group_memberships, locations, messages, sos_events
```

### `group.py`

```python
class Group(Base):
    invite_code = Column(String(12), unique=True, index=True)

class GroupMember(Base):
    role = Column(Enum(GroupRole), default=GroupRole.member)  # admin | member
```

### `location.py`

```python
class Location(Base):
    latitude, longitude  # coordenadas
    accuracy, speed, heading, altitude  # dados do GPS
    recorded_at = Column(DateTime, default=datetime.utcnow, index=True)

class Geofence(Base):
    radius_meters = Column(Integer, default=200)
```

### `message.py`

```python
class MessageType(str, enum.Enum):
    text = "text"; image = "image"; video = "video"; sos = "sos"; system = "system"

class Message(Base):
    type      = Column(Enum(MessageType))
    content   = Column(Text)       # texto ou URL S3
    media_key = Column(String(500)) # chave S3 para mídia
    is_deleted = Column(Boolean, default=False)  # soft delete

class SOSEvent(Base):
    latitude, longitude, message
    resolved = Column(Boolean, default=False)
```

## Variáveis de ambiente (`.env`)

```dotenv
DATABASE_URL=postgresql+asyncpg://minhaturma:minhaturma@localhost:5432/minhaturma
REDIS_URL=redis://:minhaturma@localhost:6379
SECRET_KEY=sua_chave_secreta_aqui_minimo_32_caracteres
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# OAuth (preenchidos quando configurado)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
APPLE_CLIENT_ID=
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY=
MICROSOFT_CLIENT_ID=
MICROSOFT_CLIENT_SECRET=
AWS_COGNITO_POOL_ID=
AWS_COGNITO_CLIENT_ID=
```
