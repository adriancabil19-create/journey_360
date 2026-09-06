import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/datasources/settings_store.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_settings.dart';

class SettingsController extends StateNotifier<UserSettings> {
  SettingsController(this._store) : super(_store.read());

  final SettingsStore _store;

  Future<void> _update(UserSettings next) async {
    state = next;
    await _store.write(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setSharingMode(SharingMode mode) =>
      _update(state.copyWith(sharingMode: mode));

  Future<void> setTrackingProfile(TrackingProfile profile) =>
      _update(state.copyWith(trackingProfile: profile));

  Future<void> setDefaultVisibility(JourneyVisibility visibility) =>
      _update(state.copyWith(defaultVisibility: visibility));

  Future<void> setJourneyAlerts(bool value) =>
      _update(state.copyWith(journeyAlerts: value));

  Future<void> setCircleAlerts(bool value) =>
      _update(state.copyWith(circleAlerts: value));

  Future<void> setSocialAlerts(bool value) =>
      _update(state.copyWith(socialAlerts: value));

  Future<void> setAutoPause(bool value) =>
      _update(state.copyWith(autoPauseEnabled: value));

  Future<void> toggleSharing() {
    final next = state.sharingMode.isOn ? SharingMode.nobody : SharingMode.everyone;
    return setSharingMode(next);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, UserSettings>(
  (ref) => SettingsController(ref.watch(settingsStoreProvider)),
);

/// Convenience: the current [ThemeMode] for `MaterialApp`.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsControllerProvider).themeMode,
);
