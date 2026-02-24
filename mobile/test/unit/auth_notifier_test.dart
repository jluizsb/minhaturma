import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/models/auth_model.dart';
import 'package:minha_turma/data/providers/auth_provider.dart';

import '../helpers/mock_auth_service.dart';

/// Cria um ProviderContainer com o MockAuthService injetado
/// e aguarda a inicialização assíncrona do AuthNotifier._init().
///
/// _init() contém até 2 pontos de await (isLoggedIn + getUser), então
/// aguardamos 3 ciclos de microtask para garantir que termine.
Future<ProviderContainer> makeContainer(MockAuthService service) async {
  final container = ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(service)],
  );
  // Aciona a criação do provider
  container.read(authProvider);
  // Aguarda múltiplos ciclos (cada await em _init() precisa de um ciclo)
  for (var i = 0; i < 5; i++) {
    await Future.delayed(Duration.zero);
  }
  return container;
}

void main() {
  group('AuthNotifier', () {
    late MockAuthService mock;

    setUp(() => mock = MockAuthService());

    // ── Inicialização ─────────────────────────────────────────────

    test('_init: sem sessão salva → isLoggedIn=false, isLoading=false', () async {
      final c = await makeContainer(mock);
      final state = c.read(authProvider);
      expect(state.isLoggedIn, isFalse);
      expect(state.isLoading, isFalse);
      c.dispose();
    });

    test('_init: com sessão salva → carrega user e isLoggedIn=true', () async {
      final user = AuthUser(id: 'u1', name: 'Cached', email: 'c@test.com');
      mock.setupLoggedIn(user);

      final c = await makeContainer(mock);
      final state = c.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.user?.email, 'c@test.com');
      c.dispose();
    });

    // ── login ─────────────────────────────────────────────────────

    test('login bem-sucedido → isLoggedIn=true, user preenchido, sem erro', () async {
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).login('joao@test.com', 'senha123');

      final state = c.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.user?.email, 'joao@test.com');
      expect(state.error, isNull);
      c.dispose();
    });

    test('login com erro → isLoggedIn=false, error preenchido', () async {
      mock.shouldThrowOnLogin = true;
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).login('x@x.com', 'errada');

      final state = c.read(authProvider);
      expect(state.isLoggedIn, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      c.dispose();
    });

    test('login 401 → mensagem "E-mail ou senha incorretos"', () async {
      mock
        ..shouldThrowOnLogin = true
        ..loginErrorCode = 401;
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).login('x@x.com', 'errada');

      expect(c.read(authProvider).error, contains('E-mail ou senha'));
      c.dispose();
    });

    test('login 400 → mensagem "E-mail já cadastrado"', () async {
      mock
        ..shouldThrowOnLogin = true
        ..loginErrorCode = 400;
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).login('x@x.com', 'senha');

      expect(c.read(authProvider).error, contains('E-mail já cadastrado'));
      c.dispose();
    });

    // ── register ──────────────────────────────────────────────────

    test('register bem-sucedido → isLoggedIn=true', () async {
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).register('João', 'joao@test.com', 'senha');

      final state = c.read(authProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.user?.name, 'João');
      c.dispose();
    });

    test('register com erro → error preenchido', () async {
      mock.shouldThrowOnRegister = true;
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).register('X', 'x@x.com', 'senha');

      expect(c.read(authProvider).isLoggedIn, isFalse);
      expect(c.read(authProvider).error, isNotNull);
      c.dispose();
    });

    // ── logout ────────────────────────────────────────────────────

    test('logout → isLoggedIn=false, user nulo', () async {
      mock.setupLoggedIn(AuthUser(id: '1', name: 'A', email: 'a@a.com'));
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).logout();

      final state = c.read(authProvider);
      expect(state.isLoggedIn, isFalse);
      expect(state.user, isNull);
      c.dispose();
    });

    // ── clearError ────────────────────────────────────────────────

    test('clearError remove o erro sem alterar outros campos', () async {
      mock.shouldThrowOnLogin = true;
      final c = await makeContainer(mock);
      await c.read(authProvider.notifier).login('x@x.com', 'wrong');

      expect(c.read(authProvider).error, isNotNull);

      c.read(authProvider.notifier).clearError();

      expect(c.read(authProvider).error, isNull);
      expect(c.read(authProvider).isLoggedIn, isFalse); // outros campos intactos
      c.dispose();
    });
  });
}
