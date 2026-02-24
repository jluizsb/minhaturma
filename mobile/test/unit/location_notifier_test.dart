import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/models/location_model.dart';
import 'package:minha_turma/data/providers/location_provider.dart';

import '../helpers/mock_location_service.dart';

ProviderContainer makeContainer(MockLocationService service) {
  return ProviderContainer(
    overrides: [locationServiceProvider.overrideWithValue(service)],
  );
}

void main() {
  group('LocationNotifier', () {
    late MockLocationService mock;

    setUp(() => mock = MockLocationService());
    tearDown(() => mock.dispose());

    // ── connect ────────────────────────────────────────────────────────

    test('connect chama LocationService.connect com token e groupId', () async {
      final c = makeContainer(mock);
      await c
          .read(locationProvider.notifier)
          .connect('my_token', 'group-1', 'user-1');

      expect(mock.connectCalled, isTrue);
      expect(mock.lastToken, 'my_token');
      expect(mock.lastGroupId, 'group-1');
      expect(c.read(locationProvider).isConnected, isTrue);
      c.dispose();
    });

    test('connect inicia startTracking', () async {
      final c = makeContainer(mock);
      await c
          .read(locationProvider.notifier)
          .connect('tok', 'grp', 'usr');

      expect(mock.startTrackingCalled, isTrue);
      c.dispose();
    });

    // ── stream ────────────────────────────────────────────────────────

    test('posição do próprio usuário atualiza myPosition', () async {
      final c = makeContainer(mock);
      await c
          .read(locationProvider.notifier)
          .connect('tok', 'grp', 'user-self');

      const loc = LocationModel(
        userId: 'user-self',
        userName: 'Eu',
        lat: -23.5,
        lng: -46.6,
        ts: 1000,
      );
      mock.controller.add(loc);
      await Future.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state.myPosition?.lat, closeTo(-23.5, 0.001));
      c.dispose();
    });

    test('posição de outro membro vai para members map', () async {
      final c = makeContainer(mock);
      await c
          .read(locationProvider.notifier)
          .connect('tok', 'grp', 'user-self');

      const loc = LocationModel(
        userId: 'user-other',
        userName: 'Outro',
        lat: -22.9,
        lng: -43.1,
        ts: 2000,
      );
      mock.controller.add(loc);
      await Future.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state.members.containsKey('user-other'), isTrue);
      expect(state.members['user-other']!.lng, closeTo(-43.1, 0.001));
      c.dispose();
    });

    // ── disconnect ────────────────────────────────────────────────────

    test('disconnect chama service.disconnect e limpa isConnected', () async {
      final c = makeContainer(mock);
      await c
          .read(locationProvider.notifier)
          .connect('tok', 'grp', 'usr');

      c.read(locationProvider.notifier).disconnect();

      expect(mock.disconnectCalled, isTrue);
      expect(c.read(locationProvider).isConnected, isFalse);
      c.dispose();
    });
  });
}
