import 'package:flutter/material.dart';

import 'enums.dart';

/// User preferences (MD section 54). Persisted locally and, when a backend is
/// configured, mirrored to the `user_settings` table.
class UserSettings {
  const UserSettings({
    this.themeMode = ThemeMode.system,
    this.sharingMode = SharingMode.everyone,
    this.trackingProfile = TrackingProfile.balanced,
    this.defaultVisibility = JourneyVisibility.private,
    this.journeyAlerts = true,
    this.circleAlerts = true,
    this.socialAlerts = false,
    this.autoPauseEnabled = true,
  });

  final ThemeMode themeMode;
  final SharingMode sharingMode;
  final TrackingProfile trackingProfile;
  final JourneyVisibility defaultVisibility;
  final bool journeyAlerts;
  final bool circleAlerts;
  final bool socialAlerts;
  final bool autoPauseEnabled;

  UserSettings copyWith({
    ThemeMode? themeMode,
    SharingMode? sharingMode,
    TrackingProfile? trackingProfile,
    JourneyVisibility? defaultVisibility,
    bool? journeyAlerts,
    bool? circleAlerts,
    bool? socialAlerts,
    bool? autoPauseEnabled,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      sharingMode: sharingMode ?? this.sharingMode,
      trackingProfile: trackingProfile ?? this.trackingProfile,
      defaultVisibility: defaultVisibility ?? this.defaultVisibility,
      journeyAlerts: journeyAlerts ?? this.journeyAlerts,
      circleAlerts: circleAlerts ?? this.circleAlerts,
      socialAlerts: socialAlerts ?? this.socialAlerts,
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme_mode': themeMode.name,
        'sharing_mode': sharingMode.name,
        'tracking_profile': trackingProfile.name,
        'default_visibility': defaultVisibility.name,
        'journey_alerts': journeyAlerts,
        'circle_alerts': circleAlerts,
        'social_alerts': socialAlerts,
        'auto_pause_enabled': autoPauseEnabled,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['theme_mode'],
          orElse: () => ThemeMode.system,
        ),
        sharingMode: SharingMode.fromName(json['sharing_mode'] as String?),
        trackingProfile:
            TrackingProfile.fromName(json['tracking_profile'] as String?),
        defaultVisibility:
            JourneyVisibility.fromName(json['default_visibility'] as String?),
        journeyAlerts: json['journey_alerts'] as bool? ?? true,
        circleAlerts: json['circle_alerts'] as bool? ?? true,
        socialAlerts: json['social_alerts'] as bool? ?? false,
        autoPauseEnabled: json['auto_pause_enabled'] as bool? ?? true,
      );
}
