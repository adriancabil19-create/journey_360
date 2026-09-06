import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/enums.dart';
import '../../data/models/journey.dart';
import '../../data/models/journey_point.dart';
import '../../data/models/journey_stats.dart';
import '../../data/models/split.dart';

/// A raw location sample handed to the recorder. Decoupled from Geolocator so
/// the maths can be unit-tested with synthetic input (MD section 60).
class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.altitude,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  /// Metres per second, as reported by the OS (may be null / -1).
  final double? speed;
  final double? altitude;
  final double? heading;

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Accumulates filtered GPS samples into distance / duration / pace / speed /
/// elevation for a single journey (MD sections 19-21, 60-61).
///
/// Pure and synchronous: feed it [add] calls and read [stats]. The provider
/// layer wires it to a real position stream and a ticking clock.
class JourneyRecorder {
  JourneyRecorder({
    required this.type,
    DateTime? startedAt,
    this.maxAccuracyMeters = 40,
    double? bodyWeightKg,
    String? id,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        _bodyWeightKg = bodyWeightKg ?? 70;

  final String id;
  JourneyType type;
  final DateTime startedAt;

  /// Samples with accuracy worse than this are ignored for statistics.
  final double maxAccuracyMeters;
  final double _bodyWeightKg;

  static const _distance = Distance();

  final List<JourneyPoint> _points = [];
  final List<Split> _splits = [];
  double _splitStartDistance = 0;
  int _splitStartSeconds = 0;
  double _lastSplitPace = 0;
  double _distanceMeters = 0;
  double _maxSpeed = 0;
  double _elevationGain = 0;
  double _currentSpeed = 0;

  bool _paused = false;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;
  DateTime? _lastTick;

  int _elapsedSeconds = 0;
  int _movingSeconds = 0;

  List<JourneyPoint> get points => List.unmodifiable(_points);
  bool get isPaused => _paused;
  int get pointCount => _points.length;

  /// Total seconds spent paused, including an in-progress pause.
  int get pausedSeconds {
    var total = _pausedTotal;
    final since = _pausedAt;
    if (since != null) total += DateTime.now().difference(since);
    return total.inSeconds;
  }

  /// Plausible ceiling for a jump between two fixes, by activity type. Anything
  /// faster is treated as GPS noise and dropped (MD section 61).
  double get _maxPlausibleSpeed => switch (type) {
        JourneyType.walking => 4.5, // ~16 km/h
        JourneyType.running => 8.5, // ~30 km/h
        JourneyType.cycling => 25, // ~90 km/h
        JourneyType.driving => 62, // ~223 km/h
        JourneyType.other => 62,
      };

  void pause() {
    if (_paused) return;
    _paused = true;
    _pausedAt = DateTime.now();
    _currentSpeed = 0;
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    final since = _pausedAt;
    if (since != null) _pausedTotal += DateTime.now().difference(since);
    _pausedAt = null;
  }

  /// Advance the wall clock. Call roughly once per second while recording.
  void tick([DateTime? now]) {
    final t = now ?? DateTime.now();
    _elapsedSeconds =
        t.difference(startedAt).inSeconds - _pausedTotal.inSeconds;
    if (_elapsedSeconds < 0) _elapsedSeconds = 0;

    final last = _lastTick;
    if (last != null && !_paused) {
      final delta = t.difference(last).inMilliseconds / 1000.0;
      if (delta > 0 && delta < 10) _movingSeconds += delta.round();
    }
    _lastTick = t;
  }

  /// Feed a location sample. Returns true if it was accepted into the route.
  bool add(LocationSample sample) {
    if (_paused) return false;
    if (sample.accuracy != null && sample.accuracy! > maxAccuracyMeters) {
      return false;
    }

    final previous = _points.isNotEmpty ? _points.last : null;
    if (previous != null) {
      final metres = _distance.as(
        LengthUnit.Meter,
        previous.latLng,
        sample.latLng,
      );
      final seconds =
          sample.timestamp.difference(previous.recordedAt).inMilliseconds /
              1000.0;
      if (seconds <= 0) return false;

      final segmentSpeed = metres / seconds;
      if (segmentSpeed > _maxPlausibleSpeed) return false; // GPS jump.

      // Ignore sub-metre jitter so a stationary phone does not accrue distance.
      if (metres < 1.0 && (sample.accuracy ?? 0) > 8) return false;

      _distanceMeters += metres;
      _currentSpeed = _resolveSpeed(sample, segmentSpeed);
      if (_currentSpeed > _maxSpeed) _maxSpeed = _currentSpeed;
      _updateSplits();

      final prevAlt = previous.altitude;
      final alt = sample.altitude;
      if (prevAlt != null && alt != null && alt - prevAlt > 0.7) {
        _elevationGain += alt - prevAlt;
      }
    }

    _points.add(JourneyPoint(
      latitude: sample.latitude,
      longitude: sample.longitude,
      recordedAt: sample.timestamp,
      altitude: sample.altitude,
      speed: sample.speed != null && sample.speed! >= 0 ? sample.speed : null,
      accuracy: sample.accuracy,
      heading: sample.heading,
    ));
    return true;
  }

  /// Close off every whole kilometre the total distance has now passed.
  void _updateSplits() {
    while (_distanceMeters - _splitStartDistance >= 1000) {
      final seconds = math.max(_movingSeconds - _splitStartSeconds, 0);
      final split = Split(
        index: _splits.length + 1,
        distanceMeters: 1000,
        seconds: seconds,
      );
      _splits.add(split);
      _lastSplitPace = split.paceSecondsPerKm;
      _splitStartDistance += 1000;
      _splitStartSeconds = _movingSeconds;
    }
  }

  List<Split> get splits => List.unmodifiable(_splits);

  double _resolveSpeed(LocationSample sample, double segmentSpeed) {
    final reported = sample.speed;
    if (reported != null && reported >= 0 && reported < _maxPlausibleSpeed) {
      // Blend OS speed with the geometric estimate for stability.
      return (reported * 0.6) + (segmentSpeed * 0.4);
    }
    return segmentSpeed;
  }

  double get _calories {
    final hours = _movingSeconds / 3600.0;
    if (hours <= 0) return 0;
    final speedKmh = _movingSeconds > 0
        ? (_distanceMeters / _movingSeconds) * 3.6
        : 0.0;
    final met = switch (type) {
      JourneyType.walking => speedKmh < 5 ? 3.0 : 4.3,
      JourneyType.running => speedKmh < 8
          ? 8.0
          : speedKmh < 11
              ? 10.0
              : 12.5,
      JourneyType.cycling => speedKmh < 19 ? 6.0 : 8.5,
      JourneyType.driving => 1.5,
      JourneyType.other => 3.5,
    };
    return met * _bodyWeightKg * hours;
  }

  JourneyStats get stats => JourneyStats(
        type: type,
        distanceMeters: _distanceMeters,
        elapsedSeconds: _elapsedSeconds,
        movingSeconds: _movingSeconds,
        currentSpeed: _currentSpeed,
        maxSpeed: _maxSpeed,
        elevationGain: _elevationGain,
        calories: _calories,
        pointCount: _points.length,
        currentSplitMeters: _distanceMeters - _splitStartDistance,
        currentSplitSeconds: math.max(_movingSeconds - _splitStartSeconds, 0),
        lastSplitPace: _lastSplitPace,
        splitCount: _splits.length,
      );

  /// Freeze the recording into a [Journey] for persistence. When [ongoing] is
  /// true the result represents an in-progress snapshot (no end time).
  Journey finish({
    JourneyVisibility visibility = JourneyVisibility.private,
    bool ongoing = false,
  }) {
    final now = DateTime.now();
    final first = _points.isNotEmpty ? _points.first : null;
    final last = _points.isNotEmpty ? _points.last : null;
    final movingSecs = math.max(_movingSeconds, 0);
    return Journey(
      id: id,
      type: type,
      startedAt: startedAt,
      endedAt: ongoing ? null : now,
      distanceMeters: _distanceMeters,
      durationSeconds: math.max(_elapsedSeconds, 0),
      movingSeconds: movingSecs,
      avgSpeed: movingSecs > 0 ? _distanceMeters / movingSecs : 0,
      maxSpeed: _maxSpeed,
      elevationGain: _elevationGain,
      calories: _calories,
      visibility: visibility,
      startLat: first?.latitude,
      startLng: first?.longitude,
      endLat: last?.latitude,
      endLng: last?.longitude,
      route: List.of(_points),
      splits: List.of(_splits),
    );
  }

  /// A non-destructive in-progress snapshot for crash-safe resume.
  Journey snapshot() => finish(ongoing: true);

  /// Rebuild a recorder from a previously-persisted [Journey] snapshot so an
  /// interrupted journey can be resumed (MD section 47).
  factory JourneyRecorder.fromJourney(
    Journey journey, {
    Duration pausedTotal = Duration.zero,
  }) {
    final recorder = JourneyRecorder(
      type: journey.type,
      startedAt: journey.startedAt,
      id: journey.id,
    );
    recorder._pausedTotal = pausedTotal;
    for (final p in journey.route) {
      recorder.add(LocationSample(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.recordedAt,
        accuracy: p.accuracy,
        speed: p.speed,
        altitude: p.altitude,
        heading: p.heading,
      ));
    }
    if (journey.movingSeconds > recorder._movingSeconds) {
      recorder._movingSeconds = journey.movingSeconds;
    }
    return recorder;
  }
}
