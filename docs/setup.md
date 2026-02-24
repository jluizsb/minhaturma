# Setup — Ambiente de desenvolvimento

## Pré-requisitos

| Ferramenta | Versão | Instalação |
|---|---|---|
| Python | 3.13.x | via pyenv |
| FVM (Flutter) | — | `brew install fvm` |
| Flutter | 3.41.2 stable | `fvm use 3.41.2 --global` |
| Docker Desktop | latest | brew / site oficial |
| Xcode | 26.2+ | App Store |
| CocoaPods | 1.16.2+ | `brew install cocoapods` |
| Android Studio | latest | site oficial |

## 1. Clonar o repositório

```bash
git clone https://github.com/jluizsb/minhaturma.git
cd minhaturma
```

## 2. Backend

### 2.1 Criar virtualenv

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Mac/Linux
# .venv\Scripts\activate          # Windows
```

### 2.2 Instalar dependências

```bash
pip install -r requirements.txt
```

### 2.3 Configurar variáveis de ambiente

```bash
cp .env.example .env
```

Edite `.env` com os valores locais:

```dotenv
DATABASE_URL=postgresql+asyncpg://minhaturma:minhaturma@localhost:5432/minhaturma
REDIS_URL=redis://:minhaturma@localhost:6379
SECRET_KEY=mude_para_uma_chave_secreta_de_pelo_menos_32_chars
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30
```

### 2.4 Subir banco e Redis (Docker)

```bash
docker compose -f backend/docker-compose.yml up -d db redis
```

Verificar containers ativos:
```bash
docker compose -f backend/docker-compose.yml ps
```

Saída esperada:
```
NAME          IMAGE              STATUS
backend-db-1  postgres:16-alpine Running (healthy)
backend-redis-1 redis:7-alpine   Running
```

### 2.5 Rodar as migrações

```bash
cd backend
alembic upgrade head
```

### 2.6 Iniciar a API

```bash
uvicorn main:app --reload
```

Verificar:
- Health check: `GET http://localhost:8000/health` → `{"status":"ok","version":"1.0.0"}`
- Docs interativas: http://localhost:8000/docs

### 2.7 Rodar os testes

```bash
cd backend
pytest -v
```

Saída esperada: `42 passed`

---

## 3. Mobile (Flutter)

### 3.1 Instalar dependências

```bash
cd mobile
fvm flutter pub get
```

### 3.2 iOS (apenas Mac)

```bash
cd mobile/ios
pod install
cd ..
```

### 3.3 Rodar no simulador iOS

Listar simuladores disponíveis:
```bash
fvm flutter devices
```

Iniciar (com o backend rodando em localhost):
```bash
fvm flutter run -d 9F364801-0FF1-4F25-8F4D-1AE887371D0C \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

### 3.4 Rodar no emulador Android

```bash
fvm flutter emulators --launch Medium_Phone_API_36.1
fvm flutter run -d Medium_Phone_API_36.1 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

> Use `10.0.2.2` no Android — é o alias para `localhost` da máquina host dentro do emulador.

### 3.5 Rodar os testes Flutter

```bash
cd mobile
fvm flutter test
```

Saída esperada: `53 tests passed`

---

## 4. Verificação end-to-end

Com o backend rodando e o simulador aberto:

1. Abra o app → deve aparecer a tela de login
2. Toque em "Não tem conta? Cadastre-se"
3. Preencha nome, e-mail, senha e confirme → toque "Criar conta"
4. Deve navegar para `/map` (tela do mapa, pode ser esqueleto)
5. Feche o app e reabra → deve ir direto para `/map` (sessão persistida)
6. Faça logout → deve voltar para `/login`

Validação via Swagger (`http://localhost:8000/docs`):
1. `POST /api/v1/auth/register` — cria usuário
2. `POST /api/v1/auth/login` — retorna tokens
3. Autorize com o access token (botão "Authorize" no Swagger)
4. `GET /api/v1/auth/me` — retorna dados do usuário logado
5. `POST /api/v1/auth/logout` — invalida o token
6. `GET /api/v1/auth/me` novamente → deve retornar 401

---

## 5. Solução de problemas frequentes

### Backend: `asyncpg` não compila no Python 3.13
```bash
pip install "asyncpg==0.30.0"
```

### Backend: mapper error `GroupMember not found`
Certifique-se de que `main.py` importa todos os modelos explicitamente antes de registrar os routers.

### Backend: `datetime` timezone error com PostgreSQL
Use `datetime.now(UTC).replace(tzinfo=None)` — nunca `datetime.utcnow()` (deprecated) e nunca `datetime.now(timezone.utc)` sem o `.replace(tzinfo=None)` para colunas `TIMESTAMP WITHOUT TIME ZONE`.

### Mobile: `flutter pub get` falha com conflito de versões
Confira se as versões no `pubspec.yaml` estão alinhadas com o arquivo `pubspec.lock` commitado. Em caso de conflito, rode `fvm flutter pub upgrade`.

### Mobile: `localhost` não conecta no emulador Android
Use `10.0.2.2` no lugar de `localhost` ao passar `API_BASE_URL` para o emulador Android.

### iOS: `pod install` falha
```bash
sudo gem install cocoapods
cd mobile/ios && pod deintegrate && pod install
```

### Redis: `WRONGPASS invalid username-password pair`
Confirme que o `REDIS_URL` no `.env` está no formato `redis://:senha@host:port` (note o `:` antes da senha — significa usuário padrão vazio).
