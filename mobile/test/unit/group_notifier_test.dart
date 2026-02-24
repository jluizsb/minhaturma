import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/providers/group_provider.dart';

import '../helpers/mock_group_service.dart';

ProviderContainer makeContainer(MockGroupService service) {
  return ProviderContainer(
    overrides: [groupServiceProvider.overrideWithValue(service)],
  );
}

void main() {
  group('GroupNotifier', () {
    late MockGroupService mock;

    setUp(() => mock = MockGroupService());

    // ── loadGroups ──────────────────────────────────────────────────────

    test('loadGroups: lista vazia → state.groups vazio', () async {
      final c = makeContainer(mock);
      await c.read(groupProvider.notifier).loadGroups();

      expect(c.read(groupProvider).groups, isEmpty);
      expect(c.read(groupProvider).isLoading, isFalse);
      c.dispose();
    });

    test('loadGroups: após createGroup → retorna o grupo criado', () async {
      final c = makeContainer(mock);
      await c.read(groupProvider.notifier).createGroup('Família', null);
      await c.read(groupProvider.notifier).loadGroups();

      expect(c.read(groupProvider).groups, hasLength(1));
      expect(c.read(groupProvider).groups.first.name, 'Família');
      c.dispose();
    });

    // ── createGroup ─────────────────────────────────────────────────────

    test('createGroup bem-sucedido → grupo adicionado à lista', () async {
      final c = makeContainer(mock);
      final result =
          await c.read(groupProvider.notifier).createGroup('Turma do João', 'desc');

      expect(result, isNotNull);
      expect(c.read(groupProvider).groups, hasLength(1));
      expect(c.read(groupProvider).error, isNull);
      c.dispose();
    });

    test('createGroup com erro → error preenchido, lista inalterada', () async {
      mock.shouldThrowOnCreate = true;
      final c = makeContainer(mock);
      final result = await c.read(groupProvider.notifier).createGroup('X', null);

      expect(result, isNull);
      expect(c.read(groupProvider).groups, isEmpty);
      expect(c.read(groupProvider).error, isNotNull);
      c.dispose();
    });

    // ── joinGroup ───────────────────────────────────────────────────────

    test('joinGroup bem-sucedido → grupo adicionado', () async {
      final c = makeContainer(mock);
      final result = await c.read(groupProvider.notifier).joinGroup('TESTCODE');

      expect(result, isNotNull);
      expect(c.read(groupProvider).groups, hasLength(1));
      c.dispose();
    });

    test('joinGroup código inválido (404) → mensagem de erro', () async {
      mock
        ..shouldThrowOnJoin = true
        ..joinErrorCode = 404;
      final c = makeContainer(mock);
      final result = await c.read(groupProvider.notifier).joinGroup('INVALIDO');

      expect(result, isNull);
      expect(c.read(groupProvider).error, contains('não encontrado'));
      c.dispose();
    });

    // ── leaveGroup ──────────────────────────────────────────────────────

    test('leaveGroup → grupo removido da lista', () async {
      final c = makeContainer(mock);
      final group =
          await c.read(groupProvider.notifier).createGroup('Família', null);
      expect(c.read(groupProvider).groups, hasLength(1));

      await c.read(groupProvider.notifier).leaveGroup(group!.id);
      expect(c.read(groupProvider).groups, isEmpty);
      c.dispose();
    });
  });
}
