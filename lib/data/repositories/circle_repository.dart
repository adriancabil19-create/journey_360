import '../datasources/supabase_journey_source.dart';
import '../models/circle.dart';
import '../models/live_location.dart';

/// Circles and their realtime member positions (MD sections 14-15).
///
/// Requires a backend – without one, circles simply return empty and the UI
/// shows an explanatory empty state.
class CircleRepository {
  CircleRepository(this._remote);

  final SupabaseJourneySource _remote;

  bool get isEnabled => _remote.isEnabled;

  Future<List<Circle>> circles() =>
      _remote.isEnabled ? _remote.fetchCircles() : Future.value(const []);

  Future<Circle> create(String name) => _remote.createCircle(name);

  Future<void> join(String inviteCode) => _remote.joinCircle(inviteCode);

  Stream<List<LiveLocation>> watchMembers(String circleId) =>
      _remote.watchCircleMembers(circleId);
}
