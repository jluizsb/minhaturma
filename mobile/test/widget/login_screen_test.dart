import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:minha_turma/data/providers/auth_provider.dart';
import 'package:minha_turma/presentation/screens/auth/login_screen.dart';

import '../helpers/mock_auth_service.dart';

GoRouter _testRouter(MockAuthService service) => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('Cadastro'))),
        GoRoute(path: '/map', builder: (_, __) => const Scaffold(body: Text('Mapa'))),
      ],
    );

Widget _buildApp(MockAuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: _testRouter(service)),
    );

void main() {
  group('LoginScreen', () {
    late MockAuthService mock;

    setUp(() => mock = MockAuthService());

    // ── Renderização ──────────────────────────────────────────────

    testWidgets('renderiza sem erros', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('exibe campo de e-mail', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    });

    testWidgets('exibe campo de senha', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    });

    testWidgets('exibe botão Entrar', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('exibe link para cadastro', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
    });

    testWidgets('exibe botões sociais desabilitados', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      for (final label in ['Google', 'Facebook', 'Apple']) {
        final btn = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Continuar com $label'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(btn.onPressed, isNull, reason: '$label deve estar desabilitado');
      }
    });

    testWidgets('tooltip dos botões sociais diz "Em breve"', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Em breve',
        ),
        findsNWidgets(3),
      );
    });

    // ── Validação ─────────────────────────────────────────────────

    testWidgets('submeter sem preencher e-mail mostra erro de validação', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Informe o e-mail'), findsOneWidget);
    });

    testWidgets('submeter sem preencher senha mostra erro de validação', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'user@x.com');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Informe a senha'), findsOneWidget);
    });

    // ── Interação ─────────────────────────────────────────────────

    testWidgets('toggle de visibilidade da senha funciona', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      // Antes do toggle: ícone "mostrar senha" (visibility) visível
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Após toggle: ícone muda para "ocultar senha" (visibility_off)
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('login bem-sucedido: tela de login desaparece (loading e redirect)', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'u@u.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Após login bem-sucedido, o formulário de login não deve mais aparecer
      expect(find.text('Informe o e-mail'), findsNothing);
      expect(find.text('Informe a senha'), findsNothing);
    });

    testWidgets('login com erro exibe SnackBar', (tester) async {
      mock.shouldThrowOnLogin = true;

      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'u@u.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'errada');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
