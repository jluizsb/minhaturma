import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:minha_turma/data/providers/auth_provider.dart';
import 'package:minha_turma/presentation/screens/auth/register_screen.dart';

import '../helpers/mock_auth_service.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login'))),
        GoRoute(path: '/map', builder: (_, __) => const Scaffold(body: Text('Mapa'))),
      ],
    );

Widget _buildApp(MockAuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: _testRouter()),
    );

void main() {
  group('RegisterScreen', () {
    late MockAuthService mock;

    setUp(() => mock = MockAuthService());

    // ── Renderização ──────────────────────────────────────────────

    testWidgets('renderiza sem erros', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('exibe todos os campos do formulário', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Nome completo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirmar senha'), findsOneWidget);
    });

    testWidgets('exibe botão Criar conta', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      // FilledButton específico — evita ambiguidade com AppBar
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets('exibe link para login', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();
      expect(find.text('Já tem conta? Entrar'), findsOneWidget);
    });

    // ── Validações ────────────────────────────────────────────────

    // FilledButton único na tela — evita ambiguidade com o texto da AppBar
    final submitBtn = find.byType(FilledButton);

    // Garante visibilidade antes de preencher (campo pode estar fora da tela)
    Future<void> fill(WidgetTester tester, String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    testWidgets('submeter sem nome mostra erro', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Informe seu nome'), findsOneWidget);
    });

    testWidgets('submeter sem e-mail mostra erro', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Informe o e-mail'), findsOneWidget);
    });

    testWidgets('e-mail sem @ mostra erro de validação', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await fill(tester, 'E-mail', 'emailsemarrobase');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('E-mail inválido'), findsOneWidget);
    });

    testWidgets('senha com menos de 6 caracteres mostra erro', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await fill(tester, 'E-mail', 'joao@x.com');
      await fill(tester, 'Senha', '123');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    });

    testWidgets('confirmação diferente da senha mostra erro', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await fill(tester, 'E-mail', 'joao@x.com');
      await fill(tester, 'Senha', 'senha123');
      await fill(tester, 'Confirmar senha', 'diferente');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsOneWidget);
    });

    // ── Interação ─────────────────────────────────────────────────

    testWidgets('cadastro bem-sucedido: formulário desaparece', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await fill(tester, 'E-mail', 'joao@x.com');
      await fill(tester, 'Senha', 'senha123');
      await fill(tester, 'Confirmar senha', 'senha123');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Após cadastro bem-sucedido, mensagens de erro não devem aparecer
      expect(find.text('Informe seu nome'), findsNothing);
      expect(find.text('Informe o e-mail'), findsNothing);
    });

    testWidgets('cadastro com erro exibe SnackBar', (tester) async {
      mock.shouldThrowOnRegister = true;

      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      await fill(tester, 'Nome completo', 'João');
      await fill(tester, 'E-mail', 'joao@x.com');
      await fill(tester, 'Senha', 'senha123');
      await fill(tester, 'Confirmar senha', 'senha123');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
