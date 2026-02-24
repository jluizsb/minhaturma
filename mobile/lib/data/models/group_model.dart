class GroupMemberModel {
  final String userId;
  final String name;
  final String role;

  const GroupMemberModel({
    required this.userId,
    required this.name,
    required this.role,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) => GroupMemberModel(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'role': role,
      };
}

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final int memberCount;
  final List<GroupMemberModel> members;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.memberCount,
    this.members = const [],
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        inviteCode: json['invite_code'] as String,
        memberCount: json['member_count'] as int,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((m) => GroupMemberModel.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'invite_code': inviteCode,
        'member_count': memberCount,
        'members': members.map((m) => m.toJson()).toList(),
      };
}
