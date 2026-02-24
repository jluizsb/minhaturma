import 'package:dio/dio.dart';

import '../models/group_model.dart';

class GroupService {
  final Dio _dio;

  GroupService(this._dio);

  Future<GroupModel> createGroup(String name, String? description) async {
    final response = await _dio.post('/groups/', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<GroupModel>> listGroups() async {
    final response = await _dio.get('/groups/');
    return (response.data as List<dynamic>)
        .map((g) => GroupModel.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<GroupModel> joinGroup(String inviteCode) async {
    final response = await _dio.post('/groups/join', data: {'invite_code': inviteCode});
    return GroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String groupId) async {
    await _dio.delete('/groups/$groupId/leave');
  }
}
