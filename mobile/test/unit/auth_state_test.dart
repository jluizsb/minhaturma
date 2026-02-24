import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/models/auth_model.dart';
import 'package:minha_turma/data/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    // ── Valores padrão ────────────────────────────────────────────

    test('estado padrão: isLoading=true, isLoggedIn=false, sem user nem erro', () {
      const state = AuthState();
      expect(state.isLoading, isTrue);
      expect(state.isLoggedIn, isFalse);
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    // ── copyWith – valores primitivos ─────────────────────────────

    test('copyWith atualiza isLoggedIn', () {
      const state = AuthState(isLoading: false);
      final next = state.copyWith(isLoggedIn: true);
      expect(next.isLoggedIn, isTrue);
      expect(next.isLoading, isFalse); // outros campos mantidos
    });

    test('copyWith atualiza isLoading', () {
      const state = AuthState(isLoading: true, isLoggedIn: false);
      final next = state.copyWith(isLoading: false);
      expect(next.isLoading, isFalse);
    });

    // ── copyWith – user ───────────────────────────────────────────

    test('copyWith define novo user', () {
      const state = AuthState(isLoading: false);
      final user = AuthUser(id: '1', name: 'Ana', email: 'ana@x.com');
      final next = state.copyWith(user: user);
      expect(next.user?.id, '1');
    });

    test('copyWith com clearUser=true remove o usuário', () {
      final user = AuthUser(id: '1', name: 'Ana', email: 'ana@x.com');
      final state = AuthState(isLoading: false, user: user);
      final next = state.copyWith(clearUser: true);
      expect(next.user, isNull);
    });

    test('copyWith sem clearUser mantém user existente', () {
      final user = AuthUser(id: '1', name: 'Ana', email: 'ana@x.com');
      final state = AuthState(isLoading: false, user: user);
      final next = state.copyWith(isLoading: true);
      expect(next.user, same(user));
    });

    test('copyWith com novo user substitui o anterior', () {
      final old = AuthUser(id: '1', name: 'Antigo', email: 'old@x.com');
      final novo = AuthUser(id: '2', name: 'Novo', email: 'new@x.com');
      final state = AuthState(isLoading: false, user: old);
      final next = state.copyWith(user: novo);
      expect(next.user?.id, '2');
    });

    // ── copyWith – error ──────────────────────────────────────────

    test('copyWith define erro', () {
      const state = AuthState(isLoading: false);
      final next = state.copyWith(error: 'Credenciais inválidas');
      expect(next.error, 'Credenciais inválidas');
    });

    test('copyWith com clearError=true remove o erro', () {
      const state = AuthState(isLoading: false, error: 'algum erro');
      final next = state.copyWith(clearError: true);
      expect(next.error, isNull);
    });

    test('copyWith sem clearError mantém erro existente', () {
      const state = AuthState(isLoading: false, error: 'erro antigo');
      final next = state.copyWith(isLoading: true);
      expect(next.error, 'erro antigo');
    });

    // ── Imutabilidade ─────────────────────────────────────────────

    test('copyWith sem argumentos retorna estado com mesmos valores', () {
      final user = AuthUser(id: '1', name: 'X', email: 'x@x.com');
      final state = AuthState(
        isLoggedIn: true,
        isLoading: false,
        user: user,
        error: 'err',
      );
      final next = state.copyWith();
      expect(next.isLoggedIn, state.isLoggedIn);
      expect(next.isLoading, state.isLoading);
      expect(next.user, state.user);
      expect(next.error, state.error);
    });

    test('clearError e clearUser podem ser usados juntos', () {
      final user = AuthUser(id: '1', name: 'X', email: 'x@x.com');
      final state = AuthState(isLoading: false, user: user, error: 'err');
      final next = state.copyWith(clearError: true, clearUser: true);
      expect(next.user, isNull);
      expect(next.error, isNull);
    });
  });
}
