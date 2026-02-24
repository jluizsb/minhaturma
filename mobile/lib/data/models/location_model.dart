import 'dart:math' as math;

class LocationModel {
  final String userId;
  final String userName;
  final double lat;
  final double lng;
  final double ts; // epoch seconds

  const LocationModel({
    required this.userId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.ts,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        ts: (json['ts'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'lat': lat,
        'lng': lng,
        'ts': ts,
      };

  /// Distância em metros até outro ponto (fórmula de Haversine).
  double haversine(LocationModel other) {
    const R = 6371000.0;
    final phi1 = _toRad(lat);
    final phi2 = _toRad(other.lat);
    final dPhi = _toRad(other.lat - lat);
    final dLambda = _toRad(other.lng - lng);
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
