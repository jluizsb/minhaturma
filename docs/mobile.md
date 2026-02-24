# Mobile — Documentação

App Flutter com Riverpod (estado), GoRouter (navegação) e Dio (HTTP).

## Estrutura de arquivos

```
mobile/lib/
├── main.dart                         # Ponto de entrada: ProviderScope + MinhaTurmaApp
│
├── config/
│   ├── app_config.dart               # Constantes de configuração (URL, chaves)
│   ├── router.dart                   # GoRouter com redirect baseado em auth
│   └── theme.dart                    # Material 3: temas claro e escuro
│
├── data/
│   ├── models/
│   │   └── auth_model.dart           # AuthUser: serialização JSON manual
│   │
│   ├── providers/
│   │   └── auth_provider.dart        # AuthState + AuthNotifier + providers
│   │
│   └── services/
│       ├── auth_service.dart         # HTTP auth + SecureStorage
│       └── location_service.dart     # GPS + WebSocket (esqueleto)
│
└── presentation/
    └── screens/
        ├── auth/
        │   ├── login_screen.dart     # Tela de login (completa)
        │   └── register_screen.dart  # Tela de cadastro (completa)
        ├── map/
        │   └── map_screen.dart       # Mapa em tempo real (esqueleto)
        ├── chat/
        │   └── chat_screen.dart      # Chat do grupo (esqueleto)
        ├── sos/
        │   └── sos_screen.dart       # Botão SOS (esqueleto)
        ├── group/
        │   └── group_screen.dart     # Gerenciamento de grupo (esqueleto)
        └── profile/
            └── profile_screen.dart   # Perfil do usuário (esqueleto)
```

## Ponto de entrada — `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignora erros de init do Firebase em dev (sem google-services.json)
  }
  runApp(const ProviderScope(child: MinhaTurmaApp()));
}

class MinhaTurmaApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
    );
  }
}
```

## Configuração — `config/app_config.dart`

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const int locationUpdateIntervalSeconds = 30;
  static const int locationHistoryDays = 7;
}
```

Valores injetados em tempo de compilação via `--dart-define`:
```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=GOOGLE_MAPS_API_KEY=SUA_CHAVE
```

## Modelo de dados — `data/models/auth_model.dart`

```dart
class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id:        json['id']         as String,
    name:      json['name']       as String,
    email:     json['email']      as String,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email, 'avatar_url': avatarUrl,
  };
}
```

O modelo é **imutável** (`final`). Serialização manual (sem `json_serializable`) para evitar dependência de code generation em testes.

## Serviço de autenticação — `data/services/auth_service.dart`

### Responsabilidades

| Método | Descrição |
|---|---|
| `register(name, email, password)` | POST `/auth/register` → salva tokens + user |
| `loginWithEmail(email, password)` | POST `/auth/login` (form-urlencoded) → salva tokens + user |
| `logout()` | POST `/auth/logout` com token no header; limpa storage |
| `isLoggedIn()` | Verifica se existe access token no SecureStorage |
| `getUser()` | Lê user cacheado do SecureStorage (JSON) |
| `saveUser(user)` | Persiste user como JSON no SecureStorage |
| `getAccessToken()` | Lê access token |
| `getRefreshToken()` | Lê refresh token |
| `saveTokens(access, refresh)` | Persiste os dois tokens |

### Detalhes de implementação

**Login usa `application/x-www-form-urlencoded`** (exigido pelo `OAuth2PasswordRequestForm` do FastAPI):
```dart
final response = await _dio.post(
  '/auth/login',
  data: {'username': email, 'password': password},
  options: Options(contentType: 'application/x-www-form-urlencoded'),
);
```

**Logout ignora erros de rede** (o token será expirado de qualquer forma):
```dart
Future<void> logout() async {
  try {
    final token = await getAccessToken();
    if (token != null) {
      await _dio.post('/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    }
  } catch (_) {
    // ignora erros de rede; limpeza local acontece sempre
  } finally {
    await _storage.deleteAll();
  }
}
```

**Persistência do usuário** no SecureStorage como JSON:
```dart
await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
```

## Estado de autenticação — `data/providers/auth_provider.dart`

### `AuthState`

```dart
class AuthState {
  final bool isLoggedIn;   // default: false
  final bool isLoading;    // default: true (loading inicial do _init)
  final AuthUser? user;    // null se não autenticado
  final String? error;     // mensagem de erro legível

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    AuthUser? user,
    String? error,
    bool clearError = false,  // passa true para limpar o erro sem passar null
    bool clearUser  = false,  // passa true para limpar o user
  });
}
```

### `AuthNotifier`

```dart
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState()) {
    _init();  // executa na criação do provider
  }
```

#### `_init()` — verificação de sessão ao iniciar

```dart
Future<void> _init() async {
  try {
    final loggedIn = await _service.isLoggedIn();
    if (!mounted) return;          // guard após cada await
    if (loggedIn) {
      final user = await _service.getUser();
      if (!mounted) return;
      state = AuthState(isLoggedIn: true, isLoading: false, user: user);
    } else {
      state = const AuthState(isLoggedIn: false, isLoading: false);
    }
  } catch (_) {
    if (!mounted) return;
    state = const AuthState(isLoggedIn: false, isLoading: false);
  }
}
```

> Os guards `if (!mounted) return` são essenciais para evitar `Bad state: StateNotifier was already disposed` nos testes, onde o `ProviderContainer` pode ser descartado antes que as Futures completem.

#### `_parseError()` — mensagens por código HTTP

```dart
String _parseError(Exception e) {
  final msg = e.toString();
  if (msg.contains('400')) return 'E-mail já cadastrado.';
  if (msg.contains('401')) return 'E-mail ou senha incorretos.';
  if (msg.contains('403')) return 'Conta desativada. Contate o suporte.';
  if (msg.contains('SocketException') || msg.contains('Connection refused'))
    return 'Sem conexão com o servidor.';
  return 'Ocorreu um erro. Tente novamente.';
}
```

### Providers

```dart
// Provider do serviço (pode ser sobrescrito em testes)
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Provider principal com estado + notifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
```

## Navegação — `config/router.dart`

### Arquitetura: Riverpod ↔ GoRouter

GoRouter não se integra nativamente ao Riverpod. A solução é um `ChangeNotifier` que observa o `authProvider` e notifica o GoRouter quando o estado muda:

```dart
class _AuthRouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}
```

### Lógica de redirect

```dart
redirect: (context, state) {
  final authState = ref.read(authProvider);
  if (authState.isLoading) return null;   // aguarda _init() terminar

  final isLoggedIn   = authState.isLoggedIn;
  final isAuthRoute  = state.matchedLocation == '/login' ||
                       state.matchedLocation == '/register';

  if (!isLoggedIn && !isAuthRoute) return '/login';   // protege rotas
  if (isLoggedIn  &&  isAuthRoute) return '/map';     // redireciona após login
  return null;                                         // sem redirect
}
```

### Rotas registradas

| Path | Tela |
|---|---|
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/map` | `MapScreen` |
| `/chat/:groupId` | `ChatScreen` |
| `/sos` | `SOSScreen` |
| `/group` | `GroupScreen` |
| `/profile` | `ProfileScreen` |

## Telas de autenticação

### `LoginScreen`

- `ConsumerStatefulWidget` com `GlobalKey<FormState>`
- Campos: e-mail (TextFormField) + senha (TextFormField com toggle de visibilidade)
- Validação client-side antes de chamar o provider
- `ref.read(authProvider.notifier).login(email, password)`
- `ref.listen(authProvider, ...)` → exibe `SnackBar` em caso de erro
- Botões sociais (Google, Facebook, Apple): `onPressed: null` + `Tooltip("Em breve")`
- Após login bem-sucedido: GoRouter faz redirect automático para `/map`

**Toggle de visibilidade da senha:**
```dart
bool _obscurePassword = true;

IconButton(
  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
),
```

### `RegisterScreen`

- Campos: nome, e-mail, senha, confirmar senha
- Validação:
  - Nome: não pode estar vazio
  - E-mail: deve conter `@`
  - Senha: mínimo 6 caracteres
  - Confirmar senha: deve ser igual à senha
- `ref.read(authProvider.notifier).register(name, email, password)`
- `ref.listen` → SnackBar com mensagem de erro
- Link "Já tem conta? Entrar" navega para `/login`

## Dependências principais do `pubspec.yaml`

```yaml
dependencies:
  flutter_riverpod: ^2.5.1       # Gerenciamento de estado
  go_router: ^14.0.0             # Navegação declarativa
  dio: ^5.4.3                    # Cliente HTTP
  flutter_secure_storage: ^9.0.0 # Keychain / Keystore
  google_maps_flutter: ^2.6.0    # Mapa nativo
  geolocator: ^11.0.0            # GPS
  web_socket_channel: ^2.4.0     # WebSocket
  google_sign_in: ^6.2.1         # OAuth Google
  flutter_facebook_auth: ^7.0.1  # OAuth Facebook
  sign_in_with_apple: ^6.1.1     # OAuth Apple
  firebase_core: ^3.13.0         # Firebase base
  firebase_messaging: ^15.2.4    # Push notifications
  image_picker: ^1.0.7           # Câmera / galeria
  cached_network_image: ^3.3.1   # Cache de imagens
```

## Como rodar o app

```bash
# iOS Simulator
cd mobile
fvm flutter run -d 9F364801-0FF1-4F25-8F4D-1AE887371D0C \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Android Emulator
fvm flutter emulators --launch Medium_Phone_API_36.1
fvm flutter run -d Medium_Phone_API_36.1 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

> No emulador Android, `localhost` refere-se ao próprio emulador. Use `10.0.2.2` para acessar a máquina host.
