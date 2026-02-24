import 'package:minha_turma/data/models/auth_model.dart';
import 'package:minha_turma/data/services/auth_service.dart';

/// Mock manual do AuthService para testes.
///
/// Usa `implements` para não chamar o construtor real do AuthService
/// (que instancia Dio e FlutterSecureStorage — dependências de plataforma).
///
/// Flags de controle:
///   shouldThrowOnLogin    → simula falha no login (padrão: 401)
///   shouldThrowOnRegister → simula falha no cadastro (padrão: 400)
///   loginErrorCode        → código HTTP embutido na mensagem de erro
class MockAuthService implements AuthService {
  bool _isLoggedIn = false;
  AuthUser? _user;

  bool shouldThrowOnLogin = false;
  bool shouldThrowOnRegister = false;
  int loginErrorCode = 401;

  /// Configura o mock como se o usuário já estivesse logado.
  void setupLoggedIn(AuthUser user) {
    _isLoggedIn = true;
    _user = user;
  }

  // ── Tokens ───────────────────────────────────────────────────────

  @override
  Future<void> saveTokens(String access, String refresh) async {}

  @override
  Future<String?> getAccessToken() async => _isLoggedIn ? 'mock_access_token' : null;

  @override
  Future<String?> getRefreshToken() async => _isLoggedIn ? 'mock_refresh_token' : null;

  @override
  Future<void> clearTokens() async {
    _isLoggedIn = false;
    _user = null;
  }

  // ── Usuário persistido ───────────────────────────────────────────

  @override
  Future<void> saveUser(AuthUser user) async {
    _user = user;
  }

  @override
  Future<AuthUser?> getUser() async => _user;

  // ── Estado de sessão ─────────────────────────────────────────────

  @override
  Future<bool> isLoggedIn() async => _isLoggedIn;

  @override
  Future<bool> validateAndRefreshToken() async => _isLoggedIn;

  // ── Cadastro ─────────────────────────────────────────────────────

  @override
  Future<AuthUser> register(String name, String email, String password) async {
    if (shouldThrowOnRegister) {
      throw Exception('DioException: status 400');
    }
    final user = AuthUser(id: 'mock-id', name: name, email: email);
    _user = user;
    _isLoggedIn = true;
    return user;
  }

  // ── Login ────────────────────────────────────────────────────────

  @override
  Future<AuthUser> loginWithEmail(String email, String password) async {
    if (shouldThrowOnLogin) {
      throw Exception('DioException: status $loginErrorCode');
    }
    final user = AuthUser(id: 'mock-id', name: 'Usuário Teste', email: email);
    _user = user;
    _isLoggedIn = true;
    return user;
  }

  // ── Logout ───────────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    _isLoggedIn = false;
    _user = null;
  }
}
