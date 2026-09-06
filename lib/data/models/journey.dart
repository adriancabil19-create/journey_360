import 'package:latlong2/latlong.dart';

import 'enums.dart';
import 'journey_point.dart';
import 'split.dart';

/// A completed (or in-progress) journey and its summary statistics
/// (MD sections 18, 39).
class Journey {
  const Journey({
    required this.id,
    required this.type,
    required this.startedAt,
    this.endedAt,
    this.title,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.movingSeconds = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.elevationGain = 0,
    this.calories = 0,
    this.visibility = JourneyVisibility.private,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.route = const [],
    this.splits = const [],
    this.synced = false,
  });

  final String id;
  final JourneyType type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? title;

  final double distanceMeters;
  final int durationSeconds;
  final int movingSeconds;

  /// Metres per second.
  final double avgSpeed;
  final double maxSpeed;
  final double elevationGain;
  final double calories;

  final JourneyVisibility visibility;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;

  final List<JourneyPoint> route;
  final List<Split> splits;
  final bool synced;

  bool get isActive => endedAt == null;

  List<LatLng> get polyline => route.map((p) => p.latLng).toList();

  String get displayTitle => title ?? '${type.label} · ${_dayLabel()}';

  String _dayLabel() {
    final now = DateTime.now();
    final d = startedAt;
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Journey copyWith({
    JourneyType? type,
    DateTime? endedAt,
    String? title,
    double? distanceMeters,
    int? durationSeconds,
    int? movingSeconds,
    double? avgSpeed,
    double? maxSpeed,
    double? elevationGain,
    double? calories,
    JourneyVisibility? visibility,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    List<JourneyPoint>? route,
    List<Split>? splits,
    bool? synced,
  }) {
    return Journey(
      id: id,
      type: type ?? this.type,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      title: title ?? this.title,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      elevationGain: elevationGain ?? this.elevationGain,
      calories: calories ?? this.calories,
      visibility: visibility ?? this.visibility,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      route: route ?? this.route,
      splits: splits ?? this.splits,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson({bool includeRoute = true}) => {
        'id': id,
        'type': type.name,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt?.toUtc().toIso8601String(),
        'title': title,
        'distance_m': distanceMeters,
        'duration_seconds': durationSeconds,
        'moving_seconds': movingSeconds,
        'avg_speed': avgSpeed,
        'max_speed': maxSpeed,
        'elevation_gain': elevationGain,
        'calories': calories,
        'visibility': visibility.name,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'synced': synced,
        'splits': splits.map((s) => s.toJson()).toList(),
        if (includeRoute) 'route': route.map((p) => p.toJson()).toList(),
      };

  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
        id: json['id'] as String,
        type: JourneyType.fromName(json['type'] as String?),
        startedAt:
            DateTime.tryParse(json['started_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        endedAt: DateTime.tryParse(json['ended_at'] as String? ?? '')?.toLocal(),
        title: json['title'] as String?,
        distanceMeters: (json['distance_m'] as num?)?.toDouble() ?? 0,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        movingSeconds: (json['moving_seconds'] as num?)?.toInt() ?? 0,
        avgSpeed: (json['avg_speed'] as num?)?.toDouble() ?? 0,
        maxSpeed: (json['max_speed'] as num?)?.toDouble() ?? 0,
        elevationGain: (json['elevation_gain'] as num?)?.toDouble() ?? 0,
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        visibility: JourneyVisibility.fromName(json['visibility'] as String?),
        startLat: (json['start_lat'] as num?)?.toDouble(),
        startLng: (json['start_lng'] as num?)?.toDouble(),
        endLat: (json['end_lat'] as num?)?.toDouble(),
        endLng: (json['end_lng'] as num?)?.toDouble(),
        synced: json['synced'] as bool? ?? false,
        route: ((json['route'] as List?) ?? const [])
            .map((e) => JourneyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        splits: ((json['splits'] as List?) ?? const [])
            .map((e) => Split.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
