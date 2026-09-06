import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../core/services/location_service.dart';
import '../../data/models/enums.dart';
import '../../data/models/journey.dart';
import '../../data/models/journey_stats.dart';
import '../settings/settings_controller.dart';
import 'journey_recorder.dart';

enum TrackingPhase { idle, tracking, paused }

class TrackingState {
  const TrackingState({
    this.phase = TrackingPhase.idle,
    this.access,
    this.stats,
    this.lastPosition,
    this.route = const [],
    this.error,
    this.liveSharing = false,
    this.signalQuality = SignalQuality.none,
    this.autoPaused = false,
  });

  final TrackingPhase phase;
  final LocationAccess? access;
  final JourneyStats? stats;
  final Position? lastPosition;
  final List<LatLng> route;
  final String? error;
  final bool liveSharing;
  final SignalQuality signalQuality;
  final bool autoPaused;

  bool get isRecording =>
      phase == TrackingPhase.tracking || phase == TrackingPhase.paused;

  LatLng? get here => lastPosition == null
      ? null
      : LatLng(lastPosition!.latitude, lastPosition!.longitude);

  TrackingState copyWith({
    TrackingPhase? phase,
    LocationAccess? access,
    JourneyStats? stats,
    Position? lastPosition,
    List<LatLng>? route,
    Object? error = _sentinel,
    bool? liveSharing,
    SignalQuality? signalQuality,
    bool? autoPaused,
  }) {
    return TrackingState(
      phase: phase ?? this.phase,
      access: access ?? this.access,
      stats: stats ?? this.stats,
      lastPosition: lastPosition ?? this.lastPosition,
      route: route ?? this.route,
      error: identical(error, _sentinel) ? this.error : error as String?,
      liveSharing: liveSharing ?? this.liveSharing,
      signalQuality: signalQuality ?? this.signalQuality,
      autoPaused: autoPaused ?? this.autoPaused,
    );
  }

  static const _sentinel = Object();
}

/// Owns the live GPS subscription, the [JourneyRecorder], auto-pause, crash-safe
/// snapshots and the sync of the finished journey
/// (MD sections 12, 18-21, 46-48, 59-61).
class TrackingController extends StateNotifier<TrackingState> {
  TrackingController(this._ref) : super(const TrackingState());

  final Ref _ref;
  final Battery _battery = Battery();

  StreamSubscription<Position>? _passiveSub;
  StreamSubscription<Position>? _recordSub;
  Timer? _ticker;
  Timer? _broadcastTimer;
  Timer? _snapshotTimer;
  JourneyRecorder? _recorder;
  DateTime? _lowSpeedSince;

  static const _autoPauseSpeed = 0.7; // m/s (~2.5 km/h)
  static const _autoResumeSpeed = 1.3; // m/s (~4.7 km/h)
  static const _autoPauseAfter = Duration(seconds: 12);

  LocationService get _location => _ref.read(locationServiceProvider);

  // --- Passive location (map / dashboard) --------------------------------

  Future<LocationAccess> enablePassiveTracking() async {
    final access = await _location.ensurePermission();
    state = state.copyWith(access: access);
    if (access != LocationAccess.granted) {
      state = state.copyWith(error: _messageFor(access));
      return access;
    }
    state = state.copyWith(error: null);
    _passiveSub ??= _location
        .positionStream(profile: TrackingProfile.batterySaver)
        .listen(_onPassiveFix, onError: (_) {
      state = state.copyWith(error: 'Location updates were interrupted.');
    });

    final fix = await _location.currentPosition();
    if (fix != null && mounted) _onPassiveFix(fix);
    return access;
  }

  void _onPassiveFix(Position position) {
    if (!mounted) return;
    state = state.copyWith(
      lastPosition: position,
      signalQuality: SignalQuality.fromAccuracy(position.accuracy),
    );
    if (!state.isRecording) _maybeBroadcast(position, activity: null);
  }

  // --- Recording -------------------------------------------------------

  Future<bool> start(JourneyType type) async {
    if (state.isRecording) return true;
    final access = await _location.ensurePermission();
    state = state.copyWith(access: access);
    if (access != LocationAccess.granted) {
      state = state.copyWith(error: _messageFor(access));
      return false;
    }

    final recorder = JourneyRecorder(type: type);
    _recorder = recorder;

    final seed = state.lastPosition ?? await _location.currentPosition();
    if (seed != null) recorder.add(_sampleOf(seed));

    _beginPlumbing();
    HapticFeedback.mediumImpact();
    state = state.copyWith(
      phase: TrackingPhase.tracking,
      stats: recorder.stats,
      route: recorder.points.map((p) => p.latLng).toList(),
      autoPaused: false,
      error: null,
    );
    return true;
  }

  /// Resume a journey that was interrupted (app killed) mid-recording.
  Future<bool> resumeInterrupted() async {
    if (state.isRecording) return true;
    final snap = _ref.read(journeyRepositoryProvider).readActiveSnapshot();
    if (snap == null) return false;

    final access = await _location.ensurePermission();
    if (access != LocationAccess.granted) {
      state = state.copyWith(access: access, error: _messageFor(access));
      return false;
    }

    _recorder = JourneyRecorder.fromJourney(
      snap.journey,
      pausedTotal: Duration(seconds: snap.pausedSeconds),
    );
    _beginPlumbing();
    _bumpInterrupted();
    state = state.copyWith(
      phase: TrackingPhase.tracking,
      stats: _recorder!.stats,
      route: _recorder!.points.map((p) => p.latLng).toList(),
      autoPaused: false,
      error: null,
    );
    return true;
  }

  void _beginPlumbing() {
    final settings = _ref.read(settingsControllerProvider);
    _recordSub = _location
        .positionStream(profile: settings.trackingProfile, background: true)
        .listen(_onRecordFix, onError: (_) {
      state = state.copyWith(error: 'GPS signal lost — still recording.');
    });
    _ticker =
        Timer.periodic(const Duration(seconds: 1), (_) => _refreshStats());
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _broadcastFromRecorder(),
    );
    _snapshotTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _persistSnapshot(),
    );
  }

  void _onRecordFix(Position position) {
    final recorder = _recorder;
    if (recorder == null || !mounted) return;
    recorder.add(_sampleOf(position));
    _maybeAutoResume(position);
    state = state.copyWith(
      lastPosition: position,
      signalQuality: SignalQuality.fromAccuracy(position.accuracy),
    );
    _refreshStats();
    _maybeBroadcast(position, activity: recorder.type.verb);
  }

  void _refreshStats() {
    final recorder = _recorder;
    if (recorder == null || !mounted) return;
    if (state.phase == TrackingPhase.tracking) recorder.tick();
    _maybeAutoPause(recorder.stats.currentSpeed);
    state = state.copyWith(
      stats: recorder.stats,
      route: recorder.points.map((p) => p.latLng).toList(),
    );
  }

  void _maybeAutoPause(double currentSpeed) {
    if (!_ref.read(settingsControllerProvider).autoPauseEnabled) return;
    if (state.phase != TrackingPhase.tracking) return;
    if (currentSpeed < _autoPauseSpeed) {
      _lowSpeedSince ??= DateTime.now();
      if (DateTime.now().difference(_lowSpeedSince!) > _autoPauseAfter) {
        _recorder?.pause();
        HapticFeedback.selectionClick();
        state = state.copyWith(phase: TrackingPhase.paused, autoPaused: true);
      }
    } else {
      _lowSpeedSince = null;
    }
  }

  void _maybeAutoResume(Position position) {
    if (!state.autoPaused || state.phase != TrackingPhase.paused) return;
    final speed = position.speed >= 0 ? position.speed : 0.0;
    if (speed > _autoResumeSpeed) {
      _recorder?.resume();
      _lowSpeedSince = null;
      HapticFeedback.selectionClick();
      state = state.copyWith(phase: TrackingPhase.tracking, autoPaused: false);
    }
  }

  void pause() {
    if (state.phase != TrackingPhase.tracking) return;
    _recorder?.pause();
    _lowSpeedSince = null;
    HapticFeedback.selectionClick();
    state = state.copyWith(phase: TrackingPhase.paused, autoPaused: false);
  }

  void resume() {
    if (state.phase != TrackingPhase.paused) return;
    _recorder?.resume();
    _lowSpeedSince = null;
    HapticFeedback.selectionClick();
    state = state.copyWith(phase: TrackingPhase.tracking, autoPaused: false);
  }

  Future<Journey?> finish() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    _teardownRecording();
    HapticFeedback.mediumImpact();

    final settings = _ref.read(settingsControllerProvider);
    final journey = recorder.finish(visibility: settings.defaultVisibility);
    final saved = await _ref.read(journeyRepositoryProvider).save(journey);
    await _ref.read(journeyRepositoryProvider).clearActiveSnapshot();
    _ref.read(historyRevisionProvider.notifier).state++;
    _bumpInterrupted();

    _recorder = null;
    _lowSpeedSince = null;
    state = state.copyWith(
      phase: TrackingPhase.idle,
      stats: null,
      route: const [],
      autoPaused: false,
    );
    return saved;
  }

  Future<void> discard() async {
    _teardownRecording();
    await _ref.read(journeyRepositoryProvider).clearActiveSnapshot();
    _bumpInterrupted();
    _recorder = null;
    _lowSpeedSince = null;
    state = state.copyWith(
      phase: TrackingPhase.idle,
      stats: null,
      route: const [],
      autoPaused: false,
    );
  }

  /// Save the interrupted journey (from its snapshot) without resuming it.
  Future<Journey?> finishInterrupted() async {
    final repo = _ref.read(journeyRepositoryProvider);
    final snap = repo.readActiveSnapshot();
    if (snap == null) return null;
    final recorder = JourneyRecorder.fromJourney(
      snap.journey,
      pausedTotal: Duration(seconds: snap.pausedSeconds),
    );
    final settings = _ref.read(settingsControllerProvider);
    final journey = recorder.finish(visibility: settings.defaultVisibility);
    final saved = await repo.save(journey);
    await repo.clearActiveSnapshot();
    _ref.read(historyRevisionProvider.notifier).state++;
    _bumpInterrupted();
    return saved;
  }

  Future<void> discardInterrupted() async {
    await _ref.read(journeyRepositoryProvider).clearActiveSnapshot();
    _bumpInterrupted();
  }

  void clearError() => state = state.copyWith(error: null);

  Future<void> openSettingsPage() => _location.openAppSettings();

  // --- Snapshot / broadcast -----------------------------------------

  void _persistSnapshot() {
    final recorder = _recorder;
    if (recorder == null) return;
    _ref.read(journeyRepositoryProvider).writeActiveSnapshot(
          recorder.snapshot(),
          pausedSeconds: recorder.pausedSeconds,
        );
  }

  void _bumpInterrupted() {
    if (!mounted) return;
    _ref.read(interruptedRevisionProvider.notifier).state++;
  }

  void _broadcastFromRecorder() {
    final pos = state.lastPosition;
    if (pos == null) return;
    _maybeBroadcast(pos, activity: _recorder?.type.verb);
  }

  Future<void> _maybeBroadcast(Position position, {String? activity}) async {
    final source = _ref.read(supabaseSourceProvider);
    if (!source.isEnabled) return;
    final sharing = _ref.read(settingsControllerProvider).sharingMode.isOn;
    int? battery;
    try {
      battery = await _battery.batteryLevel;
    } catch (_) {
      battery = null;
    }
    try {
      await source.pushLiveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed >= 0 ? position.speed : null,
        heading: position.heading >= 0 ? position.heading : null,
        altitude: position.altitude,
        battery: battery,
        isSharing: sharing,
        activity: activity,
      );
      if (mounted) state = state.copyWith(liveSharing: sharing);
    } catch (_) {
      // Best-effort; the journey itself is safe locally.
    }
  }

  // --- Helpers -------------------------------------------------------

  LocationSample _sampleOf(Position p) => LocationSample(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        accuracy: p.accuracy,
        speed: p.speed,
        altitude: p.altitude,
        heading: p.heading,
      );

  void _teardownRecording() {
    _recordSub?.cancel();
    _recordSub = null;
    _ticker?.cancel();
    _ticker = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
  }

  String _messageFor(LocationAccess access) => switch (access) {
        LocationAccess.serviceDisabled =>
          'Location services are turned off on this device.',
        LocationAccess.denied =>
          'KinPulse needs location access to record workouts.',
        LocationAccess.deniedForever =>
          'Location permission is blocked. Enable it in system settings.',
        LocationAccess.unavailable =>
          'Location is unavailable on this device right now.',
        LocationAccess.granted => '',
      };

  @override
  void dispose() {
    _passiveSub?.cancel();
    _teardownRecording();
    super.dispose();
  }
}

final trackingControllerProvider =
    StateNotifierProvider<TrackingController, TrackingState>(
  (ref) => TrackingController(ref),
);
