import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/models/location_model.dart';

void main() {
  group('LocationModel.haversine', () {
    const base = LocationModel(
      userId: 'u1',
      userName: 'Teste',
      lat: -23.5505,
      lng: -46.6333,
      ts: 0,
    );

    test('distância entre pontos idênticos é zero', () {
      expect(base.haversine(base), closeTo(0.0, 0.001));
    });

    test('distância de ~11 metros (0.0001 grau de latitude)', () {
      const other = LocationModel(
        userId: 'u2',
        userName: 'Outro',
        lat: -23.5504, // ≈ 11 metros ao norte
        lng: -46.6333,
        ts: 0,
      );
      final dist = base.haversine(other);
      expect(dist, greaterThan(9));
      expect(dist, lessThan(15));
    });

    test('distância SP → RJ ≈ 360 km', () {
      const rj = LocationModel(
        userId: 'u3',
        userName: 'RJ',
        lat: -22.9068,
        lng: -43.1729,
        ts: 0,
      );
      final dist = base.haversine(rj);
      expect(dist, greaterThan(350000));
      expect(dist, lessThan(380000));
    });
  });
}
