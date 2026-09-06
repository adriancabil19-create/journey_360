import 'package:flutter/material.dart';

/// The kind of movement a journey records. A single unified concept across
/// fitness activities and vehicle drives (MD section 18).
enum JourneyType {
  walking,
  running,
  cycling,
  driving,
  other;

  String get label => switch (this) {
        JourneyType.walking => 'Walk',
        JourneyType.running => 'Run',
        JourneyType.cycling => 'Ride',
        JourneyType.driving => 'Drive',
        JourneyType.other => 'Journey',
      };

  String get verb => switch (this) {
        JourneyType.walking => 'Walking',
        JourneyType.running => 'Running',
        JourneyType.cycling => 'Cycling',
        JourneyType.driving => 'Driving',
        JourneyType.other => 'Moving',
      };

  IconData get icon => switch (this) {
        JourneyType.walking => Icons.directions_walk_rounded,
        JourneyType.running => Icons.directions_run_rounded,
        JourneyType.cycling => Icons.directions_bike_rounded,
        JourneyType.driving => Icons.directions_car_filled_rounded,
        JourneyType.other => Icons.timeline_rounded,
      };

  String get emoji => switch (this) {
        JourneyType.walking => '\u{1F6B6}',
        JourneyType.running => '\u{1F3C3}',
        JourneyType.cycling => '\u{1F6B4}',
        JourneyType.driving => '\u{1F697}',
        JourneyType.other => '\u{1F4CD}',
      };

  static JourneyType fromName(String? value) => JourneyType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => JourneyType.other,
      );
}

/// Who can see a completed journey. Defaults to private (MD section 31).
enum JourneyVisibility {
  private,
  circle,
  friends,
  public;

  String get label => switch (this) {
        JourneyVisibility.private => 'Private',
        JourneyVisibility.circle => 'Circle',
        JourneyVisibility.friends => 'Friends',
        JourneyVisibility.public => 'Public',
      };

  static JourneyVisibility fromName(String? value) =>
      JourneyVisibility.values.firstWhere(
        (v) => v.name == value,
        orElse: () => JourneyVisibility.private,
      );
}

/// Location-sharing scope for the live map (MD section 13).
enum SharingMode {
  everyone,
  selected,
  nobody;

  String get label => switch (this) {
        SharingMode.everyone => 'Everyone in circle',
        SharingMode.selected => 'Selected members',
        SharingMode.nobody => 'Nobody',
      };

  bool get isOn => this != SharingMode.nobody;

  static SharingMode fromName(String? value) => SharingMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => SharingMode.nobody,
      );
}

/// Live GPS fix quality, derived from the reported accuracy radius (MD section 61).
enum SignalQuality {
  none,
  poor,
  fair,
  good;

  String get label => switch (this) {
        SignalQuality.none => 'No GPS',
        SignalQuality.poor => 'Weak GPS',
        SignalQuality.fair => 'Fair GPS',
        SignalQuality.good => 'Strong GPS',
      };

  static SignalQuality fromAccuracy(double? metres) {
    if (metres == null || metres <= 0) return SignalQuality.none;
    if (metres <= 12) return SignalQuality.good;
    if (metres <= 30) return SignalQuality.fair;
    return SignalQuality.poor;
  }
}

/// Adaptive GPS profile controlling accuracy and update frequency (MD section 48).
enum TrackingProfile {
  batterySaver,
  balanced,
  highAccuracy;

  String get label => switch (this) {
        TrackingProfile.batterySaver => 'Battery saver',
        TrackingProfile.balanced => 'Balanced',
        TrackingProfile.highAccuracy => 'High accuracy',
      };

  /// Minimum metres of movement before a new fix is delivered.
  int get distanceFilter => switch (this) {
        TrackingProfile.batterySaver => 25,
        TrackingProfile.balanced => 10,
        TrackingProfile.highAccuracy => 5,
      };

  static TrackingProfile fromName(String? value) =>
      TrackingProfile.values.firstWhere(
        (p) => p.name == value,
        orElse: () => TrackingProfile.balanced,
      );
}
