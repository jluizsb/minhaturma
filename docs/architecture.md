# Arquitetura — MinhaTurma

## Visão geral

```
┌──────────────────────────────────────────────────────────────┐
│  Mobile (Flutter / Dart)                                     │
│                                                              │
│  GoRouter → Telas → Providers Riverpod → Serviços           │
│  (roteamento)  (UI)    (estado/lógica)   (HTTP / storage)    │
└────────────────────────────┬─────────────────────────────────┘
                             │ HTTPS / WSS
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Backend (FastAPI / Python)                                  │
│                                                              │
│  Routers (/auth, /groups, /locations, /messages, /sos)      │
│      ↓                                                       │
│  Camada de segurança (JWT decode + Redis blacklist)          │
│      ↓                                                       │
│  SQLAlchemy async → PostgreSQL                               │
│      ↓                                                       │
│  Redis (blacklist de tokens + hub WebSocket futuro)          │
└──────────────────────────────────────────────────────────────┘
```

## Stack completa

| Camada | Tecnologia | Versão |
|---|---|---|
| Mobile UI | Flutter | 3.41.2 (via FVM) |
| Linguagem mobile | Dart | SDK ≥ 3.0 |
| Estado mobile | Riverpod (StateNotifier) | ^2.5.1 |
| Navegação mobile | GoRouter | ^14.0.0 |
| HTTP mobile | Dio | ^5.4.3 |
| Storage seguro | flutter_secure_storage | ^9.0.0 |
| Backend web | FastAPI | 0.111.0 |
| ASGI server | Uvicorn | 0.29.0 |
| ORM | SQLAlchemy async | 2.0.36 |
| DB driver | asyncpg | 0.30.0 |
| Banco de dados | PostgreSQL | 16 |
| Cache / blacklist | Redis | 7 |
| Autenticação | JWT (PyJWT) + bcrypt | 2.8.0 / 5.0.0 |
| Testes backend | pytest + pytest-asyncio | 8.2.0 / 0.23.6 |
| DB de testes | SQLite in-memory (aiosqlite) | — |
| Testes mobile | flutter_test | SDK padrão |

## Fluxo de autenticação

```
Usuário            Mobile                   Backend            Redis
  │                  │                         │                 │
  │── preencheu ────►│                         │                 │
  │   formulário     │── POST /auth/login ────►│                 │
  │                  │   {email, password}      │                 │
  │                  │                         │── verifica hash │
  │                  │                         │   bcrypt        │
  │                  │◄── 200 {access_token,   │                 │
  │                  │    refresh_token, user} │                 │
  │                  │                         │                 │
  │                  │── salva tokens no       │                 │
  │                  │   Keychain/Keystore      │                 │
  │                  │                         │                 │
  │◄── navega ───────│                         │                 │
  │    para /map     │                         │                 │
  │                  │                         │                 │
  │── ação protegida►│                         │                 │
  │                  │── GET /auth/me ─────────►│                 │
  │                  │   Authorization: Bearer  │── exists        │
  │                  │                         │   bl:{token} ──►│
  │                  │                         │◄── 0 (não bl.)  │
  │                  │◄── 200 {user}           │                 │
  │                  │                         │                 │
  │── logout ────────►│                         │                 │
  │                  │── POST /auth/logout ────►│                 │
  │                  │   Authorization: Bearer  │── setex         │
  │                  │                         │   bl:{token}   ►│
  │                  │◄── 204 No Content       │                 │
  │                  │                         │                 │
  │                  │── limpa storage local   │                 │
```

## Tokens JWT

| Tipo | Duração | Campo `type` | Uso |
|---|---|---|---|
| Access token | 1 hora | `"access"` | Enviado no header `Authorization: Bearer` |
| Refresh token | 30 dias | `"refresh"` | Enviado em `POST /auth/refresh` para renovar o access token |

**Payload do JWT:**
```json
{
  "sub": "<user_uuid>",
  "type": "access",
  "exp": 1700000000
}
```

**Blacklist de logout:** ao fazer logout, o access token é inserido no Redis com TTL igual ao tempo restante de expiração (`setex("bl:{token}", ttl_restante, "1")`). Toda requisição autenticada verifica `exists("bl:{token}")` antes de prosseguir.

## Banco de dados — modelo entidade-relacionamento

```
users
├─ id (UUID PK)
├─ email (unique)
├─ name
├─ hashed_password
├─ avatar_url
├─ google_id / facebook_id / apple_id / microsoft_id / aws_cognito_id
├─ is_active, is_verified
└─ last_seen_at, created_at, updated_at

groups
├─ id (UUID PK)
├─ name, description, avatar_url
├─ invite_code (unique, 12 chars)
└─ is_active, created_at, updated_at

group_members
├─ id (UUID PK)
├─ group_id → groups.id
├─ user_id  → users.id
├─ role (admin | member)
└─ joined_at

locations
├─ id (UUID PK)
├─ user_id → users.id
├─ latitude, longitude, accuracy, speed, heading, altitude
├─ address
└─ recorded_at (index)

geofences
├─ id (UUID PK)
├─ group_id → groups.id
├─ name, latitude, longitude, radius_meters
└─ is_active, created_at

messages
├─ id (UUID PK)
├─ group_id → groups.id
├─ sender_id → users.id
├─ type (text | image | video | sos | system)
├─ content, media_key
├─ is_deleted
└─ created_at (index)

sos_events
├─ id (UUID PK)
├─ user_id → users.id
├─ latitude, longitude
├─ message
├─ resolved
└─ created_at
```

## Arquitetura AWS (planejada)

```
Internet
    │
    ▼
CloudFront CDN
    │
    ├──► S3 (mídia: imagens, vídeos)
    │
    └──► ALB (Application Load Balancer)
             │
             ▼
         ECS Fargate (containers)
             │
             ├──► RDS PostgreSQL (Multi-AZ)
             └──► ElastiCache Redis (cluster)

Auth social: AWS Cognito (Google / Facebook / Apple / Microsoft)
Push: Firebase FCM
IaC: Terraform (VPC, subnets, security groups, ECS tasks, etc.)
CI/CD: GitHub Actions → ECR → ECS rolling update
```

## Decisões técnicas relevantes

### Por que Riverpod (e não Provider ou Bloc)?
- Type-safety sem `BuildContext`
- Dependency injection nativa via `ref.watch`/`ref.read`
- `ProviderContainer` facilita testes unitários isolados
- `StateNotifier` para estado mutável com histórico explícito de mudanças

### Por que JWT próprio em vez de Cognito desde o início?
- Menor acoplamento a vendor no estágio inicial
- Mais didático para aprendizado
- Migração futura para Cognito é possível sem mudar a interface do mobile

### Por que bcrypt direto (sem passlib)?
- `passlib 1.7.4` não é compatível com `bcrypt ≥ 4.0` (atributos internos renomeados)
- `bcrypt 5.0.0` é chamado diretamente via `bcrypt.hashpw/checkpw`

### Por que UUID como PK?
- IDs não-sequenciais dificultam enumeração de recursos
- UUIDs gerados pelo banco (PostgreSQL `gen_random_uuid()`) garantem unicidade distribuída

### Por que `datetime.now(UTC).replace(tzinfo=None)` em vez de `utcnow()`?
- `datetime.utcnow()` está deprecated no Python 3.12+
- `TIMESTAMP WITHOUT TIME ZONE` no PostgreSQL rejeita datetimes timezone-aware
- O `replace(tzinfo=None)` remove o timezone antes de inserir no banco
