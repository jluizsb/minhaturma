# Testes — Documentação

## Estratégia geral

Adotamos **testes unitários e de integração** como base de segurança para evitar regressões. Todo código novo deve vir acompanhado de testes. A documentação aqui deve ser mantida sincronizada com as suítes.

### Princípios

- **Isolamento**: cada teste parte de um estado limpo (banco in-memory, mocks sem estado compartilhado)
- **Sem dependências externas**: banco real, Redis real e APIs OAuth nunca são chamados nos testes
- **Pirâmide de testes**: mais testes unitários (rápidos) do que de integração (lentos)
- **Mocks manuais**: sem frameworks de mock para reduzir acoplamento e facilitar leitura

---

## Backend (pytest)

### Localização

```
backend/tests/
├── conftest.py              # Fixtures compartilhadas
├── unit/
│   └── test_security.py     # 20 testes unitários
└── integration/
    └── test_auth.py         # 22 testes de integração
```

**Total: 42 testes** | Status: ✅ 42/42 passando

### Como rodar

```bash
cd backend
source .venv/bin/activate
pytest                        # todos os testes
pytest tests/unit/            # só unitários
pytest tests/integration/     # só integração
pytest -v                     # verbose (nome de cada teste)
pytest -k "test_login"        # filtra por nome
```

### Infraestrutura de testes — `conftest.py`

#### `FakeRedis` — substituto in-memory

```python
class FakeRedis:
    """Mock do Redis sem TTL real (adequado para testes)."""
    def __init__(self):
        self._store: dict = {}

    async def exists(self, key: str) -> int:
        return 1 if key in self._store else 0

    async def setex(self, key: str, ttl: int, value: str) -> None:
        self._store[key] = value   # TTL ignorado em testes
```

#### `db_session` — SQLite in-memory por teste

```python
@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)  # cria schema
    SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with SessionLocal() as session:
        yield session
    await engine.dispose()   # descarta o banco ao fim do teste
```

> Cada teste recebe um banco limpo e isolado. Isso elimina interferência entre testes e elimina a necessidade de rollback ou truncate.

#### `client` — AsyncClient com overrides

```python
@pytest.fixture
async def client(db_session, fake_redis):
    async def override_get_db():
        try:
            yield db_session
            await db_session.commit()
        except Exception:
            await db_session.rollback()
            raise

    async def override_get_redis():
        return fake_redis

    app.dependency_overrides[get_db] = override_get_db

    with patch("app.api.v1.auth.get_redis",       new=override_get_redis), \
         patch("app.api.dependencies.get_redis",  new=override_get_redis):
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test"
        ) as ac:
            yield ac

    app.dependency_overrides.clear()
```

> `get_redis` é patchado via `unittest.mock.patch` porque não é uma FastAPI `Depends`, mas sim chamada diretamente dentro dos handlers.

### Testes unitários — `tests/unit/test_security.py`

| Classe de teste | Casos | O que verifica |
|---|---|---|
| `TestHashPassword` | 4 | Hash retorna string, bcrypt prefix `$2b$`, hashes distintos para mesma senha |
| `TestVerifyPassword` | 4 | Senha correta retorna True, incorreta False, hash modificado False |
| `TestCreateAccessToken` | 5 | Token decodificável, campo `type == "access"`, `sub` correto, `exp` dentro do prazo |
| `TestCreateRefreshToken` | 3 | Campo `type == "refresh"`, expiração em ~30 dias |
| `TestDecodeToken` | 4 | Token válido decodifica, token expirado levanta 401, token inválido levanta 401 |

### Testes de integração — `tests/integration/test_auth.py`

| Classe | Casos | Cenário |
|---|---|---|
| `TestRegister` | 5 | Registro bem-sucedido, e-mail duplicado (400), resposta contém tokens e user, tokens decodificáveis |
| `TestLogin` | 5 | Login bem-sucedido, senha errada (401), retorna user correto, tokens válidos |
| `TestMe` | 4 | GET /me com token válido, token expirado (401), sem token (401), token de refresh (401) |
| `TestLogout` | 4 | Logout insere token na blacklist, token blacklistado → 401 em /me, refresh token não é blacklistado |
| `TestRefresh` | 4 | Refresh bem-sucedido, token de acesso rejeitado em /refresh, refresh expirado (401) |

---

## Mobile (Flutter)

### Localização

```
mobile/test/
├── helpers/
│   └── mock_auth_service.dart       # Mock manual do AuthService
├── unit/
│   ├── auth_model_test.dart         # 9 testes
│   ├── auth_notifier_test.dart      # 11 testes
│   └── auth_state_test.dart         # 11 testes
├── widget/
│   ├── login_screen_test.dart       # 14 testes
│   └── register_screen_test.dart    # 11 testes
└── widget_test.dart                 # 1 teste (smoke test do app)
```

**Total: 53 testes** | Status: ✅ 53/53 passando

### Como rodar

```bash
cd mobile
fvm flutter test                         # todos os testes
fvm flutter test test/unit/              # só unitários
fvm flutter test test/widget/            # só widget tests
fvm flutter test --reporter expanded     # verbose
fvm flutter test test/unit/auth_model_test.dart  # arquivo específico
```

### `MockAuthService` — `test/helpers/mock_auth_service.dart`

Mock manual que implementa `AuthService` sem chamadas HTTP ou SecureStorage:

```dart
class MockAuthService implements AuthService {
  bool _isLoggedIn = false;
  AuthUser? _user;

  // Flags para simular erros
  bool shouldThrowOnLogin    = false;
  bool shouldThrowOnRegister = false;
  int  loginErrorCode        = 401;

  /// Configura o mock como "já logado" com um usuário específico.
  void setupLoggedIn(AuthUser user) {
    _isLoggedIn = true;
    _user = user;
  }

  @override
  Future<AuthUser> loginWithEmail(String email, String password) async {
    if (shouldThrowOnLogin) {
      throw Exception('Error $loginErrorCode: unauthorized');
    }
    final user = AuthUser(id: 'mock-id', name: 'Mock User', email: email);
    _isLoggedIn = true;
    _user = user;
    return user;
  }

  @override
  Future<AuthUser> register(String name, String email, String password) async {
    if (shouldThrowOnRegister) throw Exception('Error 500: server error');
    final user = AuthUser(id: 'mock-id', name: name, email: email);
    _isLoggedIn = true;
    _user = user;
    return user;
  }

  // logout, isLoggedIn, getUser, saveTokens, etc. implementados de forma simples
}
```

### Testes unitários — `test/unit/`

#### `auth_model_test.dart` (9 testes)

| Grupo | Testes |
|---|---|
| `fromJson` | Todos os campos presentes, avatarUrl opcional/null, campos em falta lançam erro |
| `toJson` | Serialização correta incluindo avatarUrl nulo |
| Roundtrip | `fromJson(toJson())` preserva todos os valores |

#### `auth_state_test.dart` (11 testes)

| Grupo | Testes |
|---|---|
| Valores padrão | `isLoading=true`, `isLoggedIn=false`, `user=null`, `error=null` |
| `copyWith` primitivos | Atualiza `isLoggedIn`, atualiza `isLoading`, preserva outros campos |
| `copyWith` user | Define novo user, `clearUser=true` remove, sem `clearUser` mantém |
| `copyWith` error | Define erro, `clearError=true` remove, sem `clearError` mantém |
| Imutabilidade | `copyWith()` sem args preserva todos os valores, `clearError + clearUser` simultâneos |

#### `auth_notifier_test.dart` (11 testes)

```dart
// Helper para criar container aguardando o _init() completar
Future<ProviderContainer> makeContainer(MockAuthService service) async {
  final container = ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(service)],
  );
  container.read(authProvider);  // aciona criação do notifier
  // _init() tem até 2 pontos de await; 5 ciclos garantem conclusão
  for (var i = 0; i < 5; i++) {
    await Future.delayed(Duration.zero);
  }
  return container;
}
```

| Grupo | Testes |
|---|---|
| Inicialização | Sem sessão → `isLoggedIn=false`, com sessão → carrega user e `isLoggedIn=true` |
| `login` | Sucesso (user preenchido), falha genérica (error preenchido), erro 401 (mensagem correta), erro 400 |
| `register` | Sucesso (`isLoggedIn=true`, user.name correto), falha (error preenchido) |
| `logout` | `isLoggedIn=false`, user nulo |
| `clearError` | Remove erro sem alterar outros campos |

### Testes de widget — `test/widget/`

#### Setup compartilhado

```dart
GoRouter _testRouter() => GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/map',      builder: (_, __) => const Scaffold(body: Text('Mapa'))),
  ],
);

Widget _buildApp(MockAuthService service) => ProviderScope(
  overrides: [authServiceProvider.overrideWithValue(service)],
  child: MaterialApp.router(routerConfig: _testRouter()),
);
```

> GoRouter real é usado para validar o redirect após login/cadastro.

#### `login_screen_test.dart` (14 testes)

| Grupo | Testes |
|---|---|
| Renderização | Renderiza sem erros, campo e-mail, campo senha, botão "Entrar", link cadastro |
| Botões sociais | `onPressed == null` (desabilitados), Tooltip "Em breve" em todos os 3 |
| Validação | Sem e-mail → erro, sem senha → erro |
| Interação | Toggle visibilidade da senha (icon muda), login bem-sucedido (sem erros), login com erro → SnackBar |

#### `register_screen_test.dart` (11 testes)

| Grupo | Testes |
|---|---|
| Renderização | Renderiza sem erros, 4 campos, botão "Criar conta", link login |
| Validação | Sem nome, sem e-mail, e-mail inválido (sem @), senha curta, confirmação diferente |
| Interação | Cadastro bem-sucedido (sem erros no form), cadastro com erro → SnackBar |

**Padrões usados nos widget tests:**

```dart
// Evita ambiguidade com AppBar que também tem texto "Criar conta"
final submitBtn = find.byType(FilledButton);

// Garante visibilidade antes de interagir (campos podem estar fora da tela)
Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}
```

---

## Adicionando novos testes

### Backend

1. Crie o arquivo em `tests/unit/` ou `tests/integration/`
2. Use as fixtures `client`, `db_session`, `fake_redis` do `conftest.py`
3. Nomeie as funções `test_<ação>_<resultado_esperado>`
4. Atualize a contagem neste arquivo

### Mobile

1. Testes de modelo/lógica pura → `test/unit/`
2. Testes de tela/widget → `test/widget/`
3. Se precisar de um novo mock de serviço, adicione métodos em `mock_auth_service.dart`
4. Use `ProviderContainer` com override do provider do serviço
5. Atualize a contagem neste arquivo

---

## Contagem atual de testes

| Suíte | Arquivo | Testes |
|---|---|---|
| Backend unit | `tests/unit/test_security.py` | 20 |
| Backend integration | `tests/integration/test_auth.py` | 22 |
| **Backend total** | | **42** |
| Flutter unit | `test/unit/auth_model_test.dart` | 9 |
| Flutter unit | `test/unit/auth_state_test.dart` | 11 |
| Flutter unit | `test/unit/auth_notifier_test.dart` | 11 |
| Flutter widget | `test/widget/login_screen_test.dart` | 14 |
| Flutter widget | `test/widget/register_screen_test.dart` | 11 |
| Flutter smoke | `test/widget_test.dart` | 1 |
| **Flutter total** | | **57** |
| **TOTAL GERAL** | | **99** |
