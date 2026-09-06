import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/services/location_service.dart';
import '../data/models/enums.dart';

enum TrackingMode { passive, workout }

class TrackingEngineState {
  const TrackingEngineState({
    this.mode,
    this.route = const [],
    this.distanceMeters = 0,
    this.elapsed = Duration.zero,
    this.speedMps = 0,
    this.error,
  });

  final TrackingMode? mode;
  final List<LatLng> route;
  final double distanceMeters;
  final Duration elapsed;
  final double speedMps;
  final String? error;

  bool get isActive => mode != null;

  TrackingEngineState copyWith({
    TrackingMode? mode,
    bool clearMode = false,
    List<LatLng>? route,
    double? distanceMeters,
    Duration? elapsed,
    double? speedMps,
    String? error,
  }) => TrackingEngineState(
        mode: clearMode ? null : mode ?? this.mode,
        route: route ?? this.route,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        elapsed: elapsed ?? this.elapsed,
        speedMps: speedMps ?? this.speedMps,
        error: error,
      );
}

final trackingEngineProvider = StateNotifierProvider<TrackingEngine, TrackingEngineState>(
  (ref) => TrackingEngine(ref, ref.read(supabaseClientProvider)),
);

/// Dual-rate location engine for passive safety presence and active workouts.
class TrackingEngine extends StateNotifier<TrackingEngineState> {
  TrackingEngine(this._ref, this._client) : super(const TrackingEngineState());

  final Ref _ref;
  final SupabaseClient? _client;
  final Distance _distance = const Distance();
  StreamSubscription<Position>? _locationSubscription;
  Timer? _timer;
  DateTime? _startedAt;

  Future<void> startPassive() async {
    await stop();
    final access = await _ref.read(locationServiceProvider).ensurePermission();
    if (access != LocationAccess.granted) {
      state = state.copyWith(error: 'Location permission is required for Circle Safety.');
      return;
    }
    state = const TrackingEngineState(mode: TrackingMode.passive);
    _locationSubscription = _ref.read(locationServiceProvider).positionStream(
          profile: TrackingProfile.batterySaver,
          background: true,
          distanceFilter: 50,
        ).listen(_onPosition, onError: (_) => state = state.copyWith(error: 'Passive tracking paused.'));
  }

  Future<void> startWorkout() async {
    await stop();
    final access = await _ref.read(locationServiceProvider).ensurePermission();
    if (access != LocationAccess.granted) {
      state = state.copyWith(error: 'Location permission is required for a workout.');
      return;
    }
    _startedAt = DateTime.now();
    state = const TrackingEngineState(mode: TrackingMode.workout);
    _locationSubscription = _ref.read(locationServiceProvider).positionStream(
          profile: TrackingProfile.highAccuracy,
          background: true,
          distanceFilter: 1,
        ).listen(_onPosition, onError: (_) => state = state.copyWith(error: 'Workout GPS signal lost.'));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started != null && mounted) state = state.copyWith(elapsed: DateTime.now().difference(started));
    });
  }

  Future<void> stop() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _timer?.cancel();
    _timer = null;
    if (state.mode == TrackingMode.workout && state.route.length > 1) await _saveActivity();
    if (mounted) state = const TrackingEngineState();
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    final previous = state.route.isEmpty ? null : state.route.last;
    final additional = previous == null ? 0.0 : _distance.as(LengthUnit.Meter, previous, point);
    final route = [...state.route, point];
    state = state.copyWith(
      route: route,
      distanceMeters: state.distanceMeters + additional,
      speedMps: position.speed.isNegative ? 0 : position.speed,
      error: null,
    );
    unawaited(_pushLocation(position));
  }

  Future<void> _pushLocation(Position position) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    await client.from('user_locations').upsert({
      'user_id': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'speed_mps': position.speed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _saveActivity() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final coordinates = state.route.map((p) => [p.longitude, p.latitude]).toList();
    await client.from('activities').insert({
      'user_id': userId,
      'activity_type': 'workout',
      'distance_m': state.distanceMeters,
      'duration_seconds': state.elapsed.inSeconds,
      'route': {'type': 'LineString', 'coordinates': coordinates},
      'visibility': 'circle',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
