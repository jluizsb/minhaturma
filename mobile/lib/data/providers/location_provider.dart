import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../services/location_service.dart';

// ── Provider do serviço ───────────────────────────────────────────────────────

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Estado ────────────────────────────────────────────────────────────────────

class LocationState {
  final LocationModel? myPosition;
  final Map<String, LocationModel> members; // userId → LocationModel
  final bool isConnected;
  final String? error;

  const LocationState({
    this.myPosition,
    this.members = const {},
    this.isConnected = false,
    this.error,
  });

  LocationState copyWith({
    LocationModel? myPosition,
    Map<String, LocationModel>? members,
    bool? isConnected,
    String? error,
    bool clearError = false,
    bool clearPosition = false,
  }) {
    return LocationState(
      myPosition: clearPosition ? null : (myPosition ?? this.myPosition),
      members: members ?? this.members,
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _service;
  StreamSubscription<LocationModel>? _sub;

  LocationNotifier(this._service) : super(const LocationState());

  /// Conecta ao WebSocket e começa a ouvir posições do grupo.
  Future<void> connect(String token, String groupId, String myUserId) async {
    state = state.copyWith(clearError: true);

    try {
      await _service.connect(token, groupId);
      state = state.copyWith(isConnected: true);

      _sub = _service.stream.listen((loc) {
        if (!mounted) return;
        debugPrint('[LocationNotifier] Posição recebida: userId=${loc.userId} lat=${loc.lat} lng=${loc.lng} myId=$myUserId');
        if (loc.userId == myUserId) {
          state = state.copyWith(myPosition: loc);
        } else {
          final updated = Map<String, LocationModel>.from(state.members);
          updated[loc.userId] = loc;
          state = state.copyWith(members: updated);
          debugPrint('[LocationNotifier] Membro atualizado: members.length=${updated.length}');
        }
      });

      await _service.startTracking();
    } on Exception catch (e) {
      state = state.copyWith(
        isConnected: false,
        error: 'Erro ao conectar: ${e.toString()}',
      );
    }
  }

  /// Para rastreamento e desconecta o WebSocket.
  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _service.disconnect();
    // Só atualiza o estado se o notifier ainda estiver ativo.
    // Evita disparar notificações em widgets já descartados.
    if (mounted) {
      state = state.copyWith(isConnected: false, clearPosition: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _service.disconnect();
    super.dispose();
  }
}

// ── Provider principal ────────────────────────────────────────────────────────

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref.watch(locationServiceProvider));
});
