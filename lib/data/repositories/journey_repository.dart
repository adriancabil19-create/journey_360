import '../datasources/local_journey_store.dart';
import '../datasources/supabase_journey_source.dart';
import '../models/enums.dart';
import '../models/journey.dart';

/// The single source of truth for journeys. Reads merge the local store with the
/// backend (when configured); writes go to the local store first, then sync.
class JourneyRepository {
  JourneyRepository(this._local, this._remote);

  final LocalJourneyStore _local;
  final SupabaseJourneySource _remote;

  /// Local history, newest first – always available, even offline.
  List<Journey> localHistory() => _local.readAll();

  /// Save a finished journey and attempt to sync it upward.
  Future<Journey> save(Journey journey) async {
    await _local.upsert(journey);
    if (_remote.isEnabled) {
      try {
        await _remote.pushJourney(journey);
        await _local.markSynced(journey.id);
        return journey.copyWith(synced: true);
      } catch (_) {
        // Keep it queued locally; syncPending() will retry later.
      }
    }
    return journey;
  }

  Future<void> delete(String id) => _local.delete(id);

  // --- Crash-safe snapshot (MD section 47) -------------------------------

  Future<void> writeActiveSnapshot(Journey journey, {int pausedSeconds = 0}) =>
      _local.writeSnapshot(journey, pausedSeconds: pausedSeconds);

  ({Journey journey, int pausedSeconds})? readActiveSnapshot() =>
      _local.readSnapshot();

  Future<void> clearActiveSnapshot() => _local.clearSnapshot();

  /// Push any locally-stored journeys that never reached the backend
  /// (MD section 47).
  Future<int> syncPending() async {
    if (!_remote.isEnabled) return 0;
    var synced = 0;
    for (final journey in _local.unsynced()) {
      try {
        await _remote.pushJourney(journey);
        await _local.markSynced(journey.id);
        synced++;
      } catch (_) {
        break; // Stop on the first failure; try again next time.
      }
    }
    return synced;
  }

  /// A merged view: remote rows (if reachable) plus anything only stored
  /// locally. Falls back to local-only when the backend is unreachable.
  Future<List<Journey>> history() async {
    final local = _local.readAll();
    if (!_remote.isEnabled) return local;
    try {
      final remote = await _remote.fetchJourneys();
      final byId = {for (final j in remote) j.id: j};
      for (final j in local) {
        byId.putIfAbsent(j.id, () => j);
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return merged;
    } catch (_) {
      return local;
    }
  }

  /// Lifetime distance (metres) grouped by journey type.
  Map<JourneyType, double> lifetimeDistanceByType() {
    final totals = <JourneyType, double>{};
    for (final j in _local.readAll()) {
      totals.update(j.type, (v) => v + j.distanceMeters,
          ifAbsent: () => j.distanceMeters);
    }
    return totals;
  }

  /// Distance (metres) recorded since local midnight, by type.
  Map<JourneyType, double> todayDistanceByType() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final totals = <JourneyType, double>{};
    for (final j in _local.readAll()) {
      if (j.startedAt.isBefore(midnight)) continue;
      totals.update(j.type, (v) => v + j.distanceMeters,
          ifAbsent: () => j.distanceMeters);
    }
    return totals;
  }

  Journey? lastCompleted() {
    for (final j in _local.readAll()) {
      if (!j.isActive) return j;
    }
    return null;
  }
}
