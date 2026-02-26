import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_config.dart';
import '../models/location_model.dart';

class LocationService {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LocationModel> _locationController =
      StreamController<LocationModel>.broadcast();

  /// Conecta ao WebSocket com JWT via query param.
  /// Requer que o usuário já seja membro do [groupId].
  Future<void> connect(String token, String groupId) async {
    final wsBase = AppConfig.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api/v1', '');

    final uri = Uri.parse(
      '$wsBase/api/v1/locations/ws?token=${Uri.encodeComponent(token)}&group_id=${Uri.encodeComponent(groupId)}',
    );

    _channel = WebSocketChannel.connect(uri);
    debugPrint('[LocationService] Conectando a $uri');

    _channel!.stream.listen(
      (raw) {
        debugPrint('[LocationService] Mensagem recebida: $raw');
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'location_update') {
            _locationController.add(LocationModel.fromJson(data));
          }
        } catch (e) {
          debugPrint('[LocationService] Erro ao parsear mensagem: $e');
        }
      },
      onDone: () => debugPrint('[LocationService] WebSocket fechado (onDone)'),
      onError: (e) => debugPrint('[LocationService] Erro WebSocket: $e'),
    );
  }

  /// Stream de posições recebidas via WebSocket (de todos os membros do grupo).
  Stream<LocationModel> get stream => _locationController.stream;

  /// Envia a posição atual pelo WebSocket.
  void sendLocation(double lat, double lng) {
    _channel?.sink.add(jsonEncode({
      'lat': lat,
      'lng': lng,
      'ts': DateTime.now().millisecondsSinceEpoch / 1000.0,
    }));
  }

  /// Inicia o rastreamento de GPS e envia posições via WebSocket.
  Future<void> startTracking() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) return;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metros — throttle básico no cliente
      ),
    ).listen((pos) => sendLocation(pos.latitude, pos.longitude));
  }

  /// Para o rastreamento de GPS e fecha o WebSocket.
  void disconnect() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<bool> _requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void dispose() {
    disconnect();
    _locationController.close();
  }
}
