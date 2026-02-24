import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:minha_turma/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // E-mail único por timestamp para não colidir com runs anteriores
  final email = 'teste${DateTime.now().millisecondsSinceEpoch}@minhaturma.com';
  const senha = 'senha123';
  const nome = 'João Integração';

  testWidgets('Fluxo completo: cadastro → mapa → logout → login', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── 1. Tela de Login ──────────────────────────────────────────
    expect(find.text('MinhaTurma'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    await Future.delayed(const Duration(seconds: 1)); // pausa para screenshot

    // ── 2. Navega para Cadastro ───────────────────────────────────
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta'), findsWidgets);
    await Future.delayed(const Duration(seconds: 1));

    // ── 3. Preenche formulário de cadastro ────────────────────────
    final nameField  = find.widgetWithText(TextFormField, 'Nome completo');
    final emailField = find.widgetWithText(TextFormField, 'E-mail');
    final passField  = find.widgetWithText(TextFormField, 'Senha');
    final confField  = find.widgetWithText(TextFormField, 'Confirmar senha');

    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, nome);
    await tester.pumpAndSettle();

    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, email);
    await tester.pumpAndSettle();

    await tester.ensureVisible(passField);
    await tester.enterText(passField, senha);
    await tester.pumpAndSettle();

    await tester.ensureVisible(confField);
    await tester.enterText(confField, senha);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1)); // pausa com form preenchido

    // ── 4. Submete cadastro ───────────────────────────────────────
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle(const Duration(seconds: 5)); // aguarda API
    await Future.delayed(const Duration(seconds: 2)); // pausa na tela do mapa

    // ── 5. Verifica tela do mapa ──────────────────────────────────
    expect(find.text('MinhaTurma'), findsOneWidget); // AppBar do MapScreen
    expect(find.text('Olá, $nome!'), findsOneWidget);

    // ── 6. Faz logout ─────────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await Future.delayed(const Duration(seconds: 1));

    // ── 7. Tela de login novamente ────────────────────────────────
    expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    await Future.delayed(const Duration(seconds: 1));

    // ── 8. Preenche e faz login ───────────────────────────────────
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), senha);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1)); // pausa com form preenchido

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await Future.delayed(const Duration(seconds: 2)); // pausa na tela do mapa

    // ── 9. De volta no mapa ───────────────────────────────────────
    expect(find.text('Olá, $nome!'), findsOneWidget);
  });
}
