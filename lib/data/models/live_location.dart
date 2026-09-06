import 'package:latlong2/latlong.dart';

import '../../core/utils/initials.dart';

/// The most recent known position of a circle member, kept in the `locations`
/// table and streamed over Supabase Realtime (MD sections 11, 12).
class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.displayName,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    this.isSharing = false,
    this.activity,
    this.updatedAt,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  /// Metres per second.
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final bool isSharing;

  /// Free-text status such as "Walking" or "Driving".
  final String? activity;
  final DateTime? updatedAt;
  final String? avatarUrl;

  bool get hasPosition => latitude != null && longitude != null;

  LatLng? get latLng =>
      hasPosition ? LatLng(latitude!, longitude!) : null;

  bool get isOnline {
    final t = updatedAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(minutes: 5);
  }

  String get initials => initialsOf(displayName);

  factory LiveLocation.fromJson(Map<String, dynamic> json) => LiveLocation(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Member',
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lng'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        batteryLevel: (json['battery_level'] as num?)?.toInt(),
        isSharing: json['is_sharing'] as bool? ?? false,
        activity: json['activity'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal(),
      );
}
