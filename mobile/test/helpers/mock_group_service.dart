import 'dart:async';

import 'package:minha_turma/data/models/group_model.dart';
import 'package:minha_turma/data/services/group_service.dart';

/// Mock manual do GroupService para testes.
/// Usa `implements` para não instanciar Dio.
class MockGroupService implements GroupService {
  bool shouldThrowOnCreate = false;
  bool shouldThrowOnJoin = false;
  bool shouldThrowOnLeave = false;
  int joinErrorCode = 404;

  final List<GroupModel> _groups = [];

  GroupModel _fakeGroup(String name, String? description) => GroupModel(
        id: 'group-${name.hashCode}',
        name: name,
        description: description,
        inviteCode: 'TESTCODE',
        memberCount: 1,
        members: [
          const GroupMemberModel(userId: 'user-1', name: 'Admin', role: 'admin'),
        ],
      );

  @override
  Future<GroupModel> createGroup(String name, String? description) async {
    if (shouldThrowOnCreate) throw Exception('DioException: status 400');
    final g = _fakeGroup(name, description);
    _groups.add(g);
    return g;
  }

  @override
  Future<List<GroupModel>> listGroups() async => List.unmodifiable(_groups);

  @override
  Future<GroupModel> joinGroup(String inviteCode) async {
    if (shouldThrowOnJoin) {
      throw Exception('DioException: status $joinErrorCode');
    }
    final g = GroupModel(
      id: 'group-joined',
      name: 'Grupo Entrado',
      inviteCode: inviteCode,
      memberCount: 2,
      members: const [
        GroupMemberModel(userId: 'user-1', name: 'Admin', role: 'admin'),
        GroupMemberModel(userId: 'user-2', name: 'Membro', role: 'member'),
      ],
    );
    _groups.add(g);
    return g;
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    if (shouldThrowOnLeave) throw Exception('DioException: status 404');
    _groups.removeWhere((g) => g.id == groupId);
  }
}
