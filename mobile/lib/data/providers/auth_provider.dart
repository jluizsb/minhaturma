import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_model.dart';
import '../services/auth_service.dart';

// ── Provider do serviço ───────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── Estado ───────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = true,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    AuthUser? user,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final loggedIn = await _service.isLoggedIn();
      if (!mounted) return;
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

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.loginWithEmail(email, password);
      state = AuthState(isLoggedIn: true, isLoading: false, user: user);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        error: _parseError(e),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.register(name, email, password);
      state = AuthState(isLoggedIn: true, isLoading: false, user: user);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        error: _parseError(e),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.logout();
    state = const AuthState(isLoggedIn: false, isLoading: false);
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(Exception e) {
    final msg = e.toString();
    if (msg.contains('400')) return 'E-mail já cadastrado.';
    if (msg.contains('401')) return 'E-mail ou senha incorretos.';
    if (msg.contains('403')) return 'Conta desativada. Contate o suporte.';
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused')) {
      return 'Sem conexão com o servidor.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }
}

// ── Provider principal ────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
