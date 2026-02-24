import 'dart:async';

import 'package:minha_turma/data/models/location_model.dart';
import 'package:minha_turma/data/services/location_service.dart';

/// Mock manual do LocationService para testes.
/// Expõe [controller] para injetar eventos de localização.
class MockLocationService implements LocationService {
  final StreamController<LocationModel> controller =
      StreamController<LocationModel>.broadcast();

  bool connectCalled = false;
  bool disconnectCalled = false;
  bool startTrackingCalled = false;
  String? lastToken;
  String? lastGroupId;

  @override
  Future<void> connect(String token, String groupId) async {
    connectCalled = true;
    lastToken = token;
    lastGroupId = groupId;
  }

  @override
  Stream<LocationModel> get stream => controller.stream;

  @override
  void sendLocation(double lat, double lng) {}

  @override
  Future<void> startTracking() async {
    startTrackingCalled = true;
  }

  @override
  void disconnect() {
    disconnectCalled = true;
  }

  @override
  void dispose() {
    controller.close();
  }
}
