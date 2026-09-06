import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';

/// Local persistence for [UserSettings].
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'journey360.settings.v1';

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  UserSettings read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const UserSettings();
    try {
      return UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserSettings();
    }
  }

  Future<void> write(UserSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
