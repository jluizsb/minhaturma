import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:minha_turma/data/providers/group_provider.dart';
import 'package:minha_turma/presentation/screens/group/group_screen.dart';

import '../helpers/mock_group_service.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/group',
      routes: [
        GoRoute(path: '/group', builder: (_, __) => const GroupScreen()),
        GoRoute(path: '/map', builder: (_, __) => const Scaffold(body: Text('Mapa'))),
      ],
    );

Widget _buildApp(MockGroupService service) => ProviderScope(
      overrides: [groupServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: _testRouter()),
    );

void main() {
  group('GroupScreen', () {
    late MockGroupService mock;

    setUp(() => mock = MockGroupService());

    testWidgets('renderiza sem erros e exibe TabBar', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      expect(find.byType(GroupScreen), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('exibe as três abas', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      expect(find.text('Meus Grupos'), findsOneWidget);
      expect(find.text('Criar'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('aba Criar exibe campos de nome e descrição', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      // Navega para aba Criar
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Nome do grupo'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Descrição (opcional)'), findsOneWidget);
    });

    testWidgets('aba Entrar exibe campo de código de convite', (tester) async {
      await tester.pumpWidget(_buildApp(mock));
      await tester.pumpAndSettle();

      // Navega para aba Entrar
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Código de convite'), findsOneWidget);
    });
  });
}
