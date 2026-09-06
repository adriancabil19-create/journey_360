import '../datasources/supabase_journey_source.dart';
import '../models/circle.dart';
import '../models/live_location.dart';
import '../models/place.dart';

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

    Future<void> removeMember({required String circleId, required String userId}) =>
            _remote.removeCircleMember(circleId: circleId, userId: userId);

    Future<List<Place>> places() => _remote.fetchPlaces();

    Future<Place> createPlace({
      required String name,
      required double latitude,
      required double longitude,
      required double radiusMeters,
    }) => _remote.createPlace(
          name: name,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );

    Future<void> deletePlace(String id) => _remote.deletePlace(id);

  Stream<List<LiveLocation>> watchMembers(String circleId) =>
      _remote.watchCircleMembers(circleId);
}
