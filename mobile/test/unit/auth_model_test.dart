import 'package:flutter_test/flutter_test.dart';
import 'package:minha_turma/data/models/auth_model.dart';

void main() {
  group('AuthUser', () {
    // ── fromJson ──────────────────────────────────────────────────

    group('fromJson', () {
      test('cria objeto com todos os campos', () {
        final user = AuthUser.fromJson({
          'id': 'user-123',
          'name': 'João',
          'email': 'joao@teste.com',
          'avatar_url': 'https://cdn.example.com/avatar.jpg',
        });

        expect(user.id, 'user-123');
        expect(user.name, 'João');
        expect(user.email, 'joao@teste.com');
        expect(user.avatarUrl, 'https://cdn.example.com/avatar.jpg');
      });

      test('aceita avatar_url nulo', () {
        final user = AuthUser.fromJson({
          'id': 'u1',
          'name': 'Maria',
          'email': 'maria@teste.com',
          'avatar_url': null,
        });
        expect(user.avatarUrl, isNull);
      });

      test('aceita avatar_url ausente no mapa', () {
        final user = AuthUser.fromJson({
          'id': 'u1',
          'name': 'Pedro',
          'email': 'pedro@teste.com',
        });
        expect(user.avatarUrl, isNull);
      });
    });

    // ── toJson ────────────────────────────────────────────────────

    group('toJson', () {
      test('serializa todos os campos corretamente', () {
        final user = AuthUser(
          id: 'user-456',
          name: 'Ana',
          email: 'ana@teste.com',
          avatarUrl: 'https://cdn.example.com/ana.jpg',
        );

        final json = user.toJson();

        expect(json['id'], 'user-456');
        expect(json['name'], 'Ana');
        expect(json['email'], 'ana@teste.com');
        expect(json['avatar_url'], 'https://cdn.example.com/ana.jpg');
      });

      test('serializa avatarUrl nulo como null', () {
        final user = AuthUser(id: 'u1', name: 'Sem foto', email: 'x@x.com');
        expect(user.toJson()['avatar_url'], isNull);
      });

      test('retorna Map com exatamente 4 chaves', () {
        final json = AuthUser(id: 'u', name: 'N', email: 'e@e.com').toJson();
        expect(json.keys, containsAll(['id', 'name', 'email', 'avatar_url']));
        expect(json.length, 4);
      });
    });

    // ── roundtrip ─────────────────────────────────────────────────

    test('fromJson → toJson preserva todos os campos', () {
      final original = {
        'id': 'abc-123',
        'name': 'Carlos',
        'email': 'carlos@exemplo.com',
        'avatar_url': null,
      };

      final result = AuthUser.fromJson(original).toJson();

      expect(result['id'], original['id']);
      expect(result['name'], original['name']);
      expect(result['email'], original['email']);
      expect(result['avatar_url'], original['avatar_url']);
    });
  });
}
