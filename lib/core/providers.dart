import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/datasources/local_journey_store.dart';
import '../data/datasources/settings_store.dart';
import '../data/datasources/supabase_journey_source.dart';
import '../data/models/circle.dart';
import '../data/models/enums.dart';
import '../data/models/journey.dart';
import '../data/models/live_location.dart';
import '../data/models/sos_alert.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/circle_repository.dart';
import '../data/repositories/journey_repository.dart';
import 'services/location_service.dart';

/// Overridden in `main()` once [SharedPreferences] has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The Supabase client, or null when no backend is configured (MD section 56).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.hasSupabase) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final backendEnabledProvider = Provider<bool>(
  (ref) => ref.watch(supabaseClientProvider) != null,
);

// --- Data sources & repositories ---------------------------------------------

final localJourneyStoreProvider = Provider<LocalJourneyStore>(
  (ref) => LocalJourneyStore(ref.watch(sharedPreferencesProvider)),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(sharedPreferencesProvider)),
);

final supabaseSourceProvider = Provider<SupabaseJourneySource>(
  (ref) => SupabaseJourneySource(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => JourneyRepository(
    ref.watch(localJourneyStoreProvider),
    ref.watch(supabaseSourceProvider),
  ),
);

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => CircleRepository(ref.watch(supabaseSourceProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

// --- Auth state -------------------------------------------------------------

final authChangesProvider = StreamProvider<AuthState?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (!repo.isEnabled) return Stream.value(null);
  return repo.authChanges();
});

/// True when a Supabase session exists. Offline mode reports false; the shell is
/// still reachable via the "continue offline" path.
final signedInProvider = Provider<bool>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(authRepositoryProvider).session != null;
});

// --- Location permission ---------------------------------------------------

final locationAccessProvider = FutureProvider<LocationAccess>(
  (ref) => ref.watch(locationServiceProvider).currentAccess(),
);

// --- Journey history & derived stats -------------------------------------

/// Bumped after a journey is saved so history / totals refresh.
final historyRevisionProvider = StateProvider<int>((ref) => 0);

final journeyHistoryProvider = FutureProvider<List<Journey>>((ref) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(journeyRepositoryProvider).history();
});

final todayTotalsProvider = Provider<Map<JourneyType, double>>((ref) {
  ref.watch(historyRevisionProvider);
  return ref.watch(journeyRepositoryProvider).todayDistanceByType();
});

final lifetimeTotalsProvider = Provider<Map<JourneyType, double>>((ref) {
  ref.watch(historyRevisionProvider);
  return ref.watch(journeyRepositoryProvider).lifetimeDistanceByType();
});

final lastJourneyProvider = Provider<Journey?>((ref) {
  ref.watch(historyRevisionProvider);
  return ref.watch(journeyRepositoryProvider).lastCompleted();
});

/// Bumped whenever the crash-safe snapshot is written or cleared.
final interruptedRevisionProvider = StateProvider<int>((ref) => 0);

/// A recorded-but-unfinished journey left behind by an earlier session, or null
/// (MD section 47).
final interruptedJourneyProvider =
    Provider<({Journey journey, int pausedSeconds})?>((ref) {
  ref.watch(interruptedRevisionProvider);
  return ref.watch(journeyRepositoryProvider).readActiveSnapshot();
});

/// Distance (metres) / time (seconds) / count for the current week (from Monday).
typedef WeekTotals = ({double meters, int seconds, int count});

final weekTotalsProvider = Provider<WeekTotals>((ref) {
  ref.watch(historyRevisionProvider);
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  var meters = 0.0;
  var seconds = 0;
  var count = 0;
  for (final j in ref.watch(journeyRepositoryProvider).localHistory()) {
    if (j.startedAt.isBefore(monday)) continue;
    meters += j.distanceMeters;
    seconds += j.durationSeconds;
    count++;
  }
  return (meters: meters, seconds: seconds, count: count);
});

// --- Circles -------------------------------------------------------------

final circlesProvider = FutureProvider<List<Circle>>(
  (ref) => ref.watch(circleRepositoryProvider).circles(),
);

final circleMembersProvider =
    StreamProvider.family<List<LiveLocation>, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).watchMembers(circleId);
});

final activeSosProvider = StreamProvider.family<SosAlert?, String>((ref, circleId) {
  final source = ref.watch(supabaseSourceProvider);
  return source.watchActiveSos(circleId);
});
