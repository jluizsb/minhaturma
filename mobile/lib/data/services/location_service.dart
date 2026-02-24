import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import '../../config/app_config.dart';

class LocationService {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSubscription;

  /// Solicita permissão e inicia o envio de localização em tempo real.
  Future<void> startTracking(String groupId, String userId) async {
    final permission = await _requestPermission();
    if (!permission) return;

    final wsUrl = AppConfig.apiBaseUrl
        .replaceFirst('http', 'ws')
        .replaceFirst('/api/v1', '');

    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/api/v1/locations/ws/$groupId/$userId'),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metros
      ),
    ).listen((Position position) {
      _channel?.sink.add(jsonEncode({
        'latitude':  position.latitude,
        'longitude': position.longitude,
        'accuracy':  position.accuracy,
        'speed':     position.speed,
        'heading':   position.heading,
      }));
    });
  }

  Stream<dynamic>? get locationStream => _channel?.stream;

  void stopTracking() {
    _positionSubscription?.cancel();
    _channel?.sink.close();
  }

  Future<bool> _requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }
}
