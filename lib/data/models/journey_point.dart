import 'package:latlong2/latlong.dart';

/// A single timestamped GPS sample within a journey (MD section 40).
class JourneyPoint {
  const JourneyPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? altitude;

  /// Metres per second.
  final double? speed;
  final double? accuracy;
  final double? heading;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'heading': heading,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };

  factory JourneyPoint.fromJson(Map<String, dynamic> json) => JourneyPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        recordedAt:
            DateTime.tryParse(json['recorded_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
