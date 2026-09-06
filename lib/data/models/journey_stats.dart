import 'enums.dart';

/// Live, in-memory statistics for the journey currently being recorded.
class JourneyStats {
  const JourneyStats({
    this.type = JourneyType.running,
    this.distanceMeters = 0,
    this.elapsedSeconds = 0,
    this.movingSeconds = 0,
    this.currentSpeed = 0,
    this.maxSpeed = 0,
    this.elevationGain = 0,
    this.calories = 0,
    this.pointCount = 0,
    this.currentSplitMeters = 0,
    this.currentSplitSeconds = 0,
    this.lastSplitPace = 0,
    this.splitCount = 0,
  });

  final JourneyType type;
  final double distanceMeters;
  final int elapsedSeconds;
  final int movingSeconds;

  /// Metres per second.
  final double currentSpeed;
  final double maxSpeed;
  final double elevationGain;
  final double calories;
  final int pointCount;

  /// Distance covered so far in the current (unfinished) kilometre.
  final double currentSplitMeters;
  final int currentSplitSeconds;

  /// Pace of the most recently completed kilometre, seconds per km.
  final double lastSplitPace;
  final int splitCount;

  /// Average speed over moving time, metres per second.
  double get avgSpeed =>
      movingSeconds > 0 ? distanceMeters / movingSeconds : 0;

  /// Live pace of the current kilometre, metres per second.
  double get currentSplitSpeed =>
      currentSplitSeconds > 0 ? currentSplitMeters / currentSplitSeconds : 0;

  JourneyStats copyWith({
    JourneyType? type,
    double? distanceMeters,
    int? elapsedSeconds,
    int? movingSeconds,
    double? currentSpeed,
    double? maxSpeed,
    double? elevationGain,
    double? calories,
    int? pointCount,
    double? currentSplitMeters,
    int? currentSplitSeconds,
    double? lastSplitPace,
    int? splitCount,
  }) {
    return JourneyStats(
      type: type ?? this.type,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      elevationGain: elevationGain ?? this.elevationGain,
      calories: calories ?? this.calories,
      pointCount: pointCount ?? this.pointCount,
      currentSplitMeters: currentSplitMeters ?? this.currentSplitMeters,
      currentSplitSeconds: currentSplitSeconds ?? this.currentSplitSeconds,
      lastSplitPace: lastSplitPace ?? this.lastSplitPace,
      splitCount: splitCount ?? this.splitCount,
    );
  }
}
