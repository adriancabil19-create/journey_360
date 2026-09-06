import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/enums.dart';

/// Result of asking for location permission.
enum LocationAccess {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  unavailable,
}

/// A recoverable problem with the location stream (MD section 62).
class TrackingError implements Exception {
  const TrackingError(this.kind, this.message);
  final LocationAccess kind;
  final String message;
  @override
  String toString() => 'TrackingError($kind): $message';
}

/// Thin wrapper around Geolocator: permission handling plus a configurable
/// position stream. Never throws to the UI layer for the common failure modes –
/// callers inspect [LocationAccess] instead.
class LocationService {
  const LocationService();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationAccess> currentAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      final permission = await Geolocator.checkPermission();
      return _map(permission);
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  /// Requests permission if it has not been granted yet. The caller is expected
  /// to have shown a rationale first (MD section 63).
  Future<LocationAccess> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final access = _map(permission);
      if (access == LocationAccess.granted &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }
      return access;
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// A single fix, or null if it cannot be obtained quickly.
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// A continuous stream of fixes tuned to [profile]. Used both for the live map
  /// and for journey recording.
  Stream<Position> positionStream({
    TrackingProfile profile = TrackingProfile.balanced,
    bool background = false,
    int? distanceFilter,
  }) {
    final settings = _settingsFor(profile, background, distanceFilter);
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  LocationSettings _settingsFor(
    TrackingProfile profile,
    bool background,
    int? overrideDistanceFilter,
  ) {
    final accuracy = switch (profile) {
      TrackingProfile.batterySaver => LocationAccuracy.medium,
      TrackingProfile.balanced => LocationAccuracy.high,
      TrackingProfile.highAccuracy => LocationAccuracy.bestForNavigation,
    };
    final distanceFilter = overrideDistanceFilter ?? profile.distanceFilter;

    // Platform-specific settings enable the foreground service / background
    // updates where the OS permits them (MD section 46). On web we use the base
    // LocationSettings – the browser has no background mode.
    if (kIsWeb) {
      return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'KinPulse is recording your workout',
                  notificationText: 'Tap to return to the app',
                  enableWakeLock: true,
                )
              : null,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          allowBackgroundLocationUpdates: background,
          pauseLocationUpdatesAutomatically: true,
          activityType: ActivityType.fitness,
          showBackgroundLocationIndicator: true,
        );
      default:
        return LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        );
    }
  }

  LocationAccess _map(LocationPermission permission) => switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationAccess.granted,
        LocationPermission.denied => LocationAccess.denied,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.unableToDetermine => LocationAccess.unavailable,
      };
}
