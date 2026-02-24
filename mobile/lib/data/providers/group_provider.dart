import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../models/group_model.dart';
import '../providers/auth_provider.dart';
import '../services/group_service.dart';

// ── Provider do serviço ───────────────────────────────────────────────────────

final groupServiceProvider = Provider<GroupService>((ref) {
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  // Interceptor para adicionar token em todas as requisições
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await ref.read(authServiceProvider).getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        handler.next(options);
      },
    ),
  );

  return GroupService(dio);
});

// ── Estado ────────────────────────────────────────────────────────────────────

class GroupState {
  final List<GroupModel> groups;
  final bool isLoading;
  final String? error;

  const GroupState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  GroupState copyWith({
    List<GroupModel>? groups,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class GroupNotifier extends StateNotifier<GroupState> {
  final GroupService _service;

  GroupNotifier(this._service) : super(const GroupState());

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final groups = await _service.listGroups();
      state = state.copyWith(groups: groups, isLoading: false);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<GroupModel?> createGroup(String name, String? description) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final group = await _service.createGroup(name, description);
      state = state.copyWith(
        groups: [...state.groups, group],
        isLoading: false,
      );
      return group;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return null;
    }
  }

  Future<GroupModel?> joinGroup(String inviteCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final group = await _service.joinGroup(inviteCode);
      state = state.copyWith(
        groups: [...state.groups, group],
        isLoading: false,
      );
      return group;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
      return null;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.leaveGroup(groupId);
      state = state.copyWith(
        groups: state.groups.where((g) => g.id != groupId).toList(),
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _msg(Exception e) {
    final s = e.toString();
    if (s.contains('404')) return 'Grupo não encontrado.';
    if (s.contains('400')) return 'Você já é membro deste grupo.';
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'Sem conexão com o servidor.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }
}

// ── Provider principal ────────────────────────────────────────────────────────

final groupProvider = StateNotifierProvider<GroupNotifier, GroupState>((ref) {
  return GroupNotifier(ref.watch(groupServiceProvider));
});
