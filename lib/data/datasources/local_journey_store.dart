import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journey.dart';

/// On-device persistence for journeys. This is the primary sink: a journey is
/// always written here first so it survives a network outage or the app being
/// killed mid-recording (MD section 47). When a backend is configured the
/// repository layer syncs unsynced rows upward.
class LocalJourneyStore {
  LocalJourneyStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'journey360.journeys.v1';
  static const _snapshotKey = 'journey360.activeSnapshot.v1';

  static Future<LocalJourneyStore> open() async =>
      LocalJourneyStore(await SharedPreferences.getInstance());

  List<Journey> readAll() {
    final raw = _prefs.getStringList(_key) ?? const [];
    final journeys = <Journey>[];
    for (final entry in raw) {
      try {
        journeys.add(
          Journey.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip a corrupt row rather than losing the whole history.
      }
    }
    journeys.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return journeys;
  }

  Future<void> upsert(Journey journey) async {
    final all = readAll()..removeWhere((j) => j.id == journey.id);
    all.add(journey);
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _write(all);
  }

  Future<void> delete(String id) async {
    final all = readAll()..removeWhere((j) => j.id == id);
    await _write(all);
  }

  List<Journey> unsynced() => readAll().where((j) => !j.synced).toList();

  Future<void> markSynced(String id) async {
    final all = readAll();
    final idx = all.indexWhere((j) => j.id == id);
    if (idx == -1) return;
    all[idx] = all[idx].copyWith(synced: true);
    await _write(all);
  }

  Future<void> _write(List<Journey> journeys) async {
    await _prefs.setStringList(
      _key,
      journeys.map((j) => jsonEncode(j.toJson())).toList(),
    );
  }

  // --- In-progress snapshot (crash-safe resume) ---------------------------

  /// Persist the journey currently being recorded so it survives the app being
  /// killed mid-recording (MD section 47).
  Future<void> writeSnapshot(Journey journey, {int pausedSeconds = 0}) async {
    await _prefs.setString(
      _snapshotKey,
      jsonEncode({
        'paused_seconds': pausedSeconds,
        'journey': journey.toJson(),
      }),
    );
  }

  ({Journey journey, int pausedSeconds})? readSnapshot() {
    final raw = _prefs.getString(_snapshotKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final journey =
          Journey.fromJson(map['journey'] as Map<String, dynamic>);
      // Ignore a stale snapshot with no real data.
      if (journey.route.length < 2) return null;
      return (
        journey: journey,
        pausedSeconds: (map['paused_seconds'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSnapshot() async => _prefs.remove(_snapshotKey);
}
