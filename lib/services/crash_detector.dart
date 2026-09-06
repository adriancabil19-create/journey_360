import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

class CrashEvent {
  const CrashEvent({required this.gForce, required this.detectedAt});

  final double gForce;
  final DateTime detectedAt;
}

/// Watches raw accelerometer data and reports a high-confidence impact.
class CrashDetector {
  CrashDetector({
    required this.endpoint,
    this.thresholdG = 3.5,
    this.cooldown = const Duration(seconds: 30),
  });

  final String endpoint;
  final double thresholdG;
  final Duration cooldown;
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastDetection;

  void start({required Future<void> Function(CrashEvent event) onCrash}) {
    _subscription ??= accelerometerEventStream().listen((event) {
      final gForce = _magnitude(event) / 9.80665;
      final last = _lastDetection;
      if (gForce < thresholdG || (last != null && DateTime.now().difference(last) < cooldown)) return;
      _lastDetection = DateTime.now();
      unawaited(onCrash(CrashEvent(gForce: gForce, detectedAt: _lastDetection!)));
    });
  }

  Future<http.Response> dispatch({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String alertType,
    required double speedMph,
  }) {
    return http.post(
      Uri.parse(endpoint),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'alertType': alertType,
        'speedMph': speedMph,
      }),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  double _magnitude(AccelerometerEvent event) =>
      math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
}
