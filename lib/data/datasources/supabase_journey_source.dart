import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../models/journey.dart';
import '../models/live_location.dart';
import '../models/place.dart';
import '../models/sos_alert.dart';

/// All Supabase reads/writes for journeys, live locations and circles.
///
/// Every method is a no-op (or returns empty) when [client] is null, so the app
/// runs fully offline until `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` are
/// supplied (MD sections 43, 56).
class SupabaseJourneySource {
  const SupabaseJourneySource(this.client);

  final SupabaseClient? client;

  bool get isEnabled => client != null;
  String? get userId => client?.auth.currentUser?.id;

  // --- Journeys -------------------------------------------------------------

  Future<void> pushJourney(Journey journey) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return;

    await c.from('journeys').upsert({
      'id': journey.id,
      'user_id': uid,
      'type': journey.type.name,
      'title': journey.title,
      'started_at': journey.startedAt.toUtc().toIso8601String(),
      'ended_at': journey.endedAt?.toUtc().toIso8601String(),
      'distance_m': journey.distanceMeters,
      'duration_seconds': journey.durationSeconds,
      'moving_seconds': journey.movingSeconds,
      'avg_speed': journey.avgSpeed,
      'max_speed': journey.maxSpeed,
      'elevation_gain': journey.elevationGain,
      'calories': journey.calories,
      'visibility': journey.visibility.name,
      'start_lat': journey.startLat,
      'start_lng': journey.startLng,
      'end_lat': journey.endLat,
      'end_lng': journey.endLng,
    });

    if (journey.route.isNotEmpty) {
      // Clear any partially-synced points first so a retry cannot duplicate.
      await c.from('journey_points').delete().eq('journey_id', journey.id);
      final rows = journey.route
          .map((p) => {
                'journey_id': journey.id,
                'lat': p.latitude,
                'lng': p.longitude,
                'altitude': p.altitude,
                'speed': p.speed,
                'accuracy': p.accuracy,
                'heading': p.heading,
                'recorded_at': p.recordedAt.toUtc().toIso8601String(),
              })
          .toList();
      await c.from('journey_points').insert(rows);
    }
  }

  Future<List<Journey>> fetchJourneys({int limit = 100}) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return const [];
    final rows = await c
        .from('journeys')
        .select()
        .eq('user_id', uid)
        .order('started_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Journey.fromJson({
              ...r as Map<String, dynamic>,
              'synced': true,
            }))
        .toList();
  }

  // --- Live location ------------------------------------------------------

  Future<void> pushLiveLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
    int? battery,
    required bool isSharing,
    String? activity,
  }) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return;
    await c.from('locations').upsert({
      'user_id': uid,
      'lat': latitude,
      'lng': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'battery_level': battery,
      'is_sharing': isSharing,
      'activity': activity,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> setSharing(bool isSharing) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return;
    await c.from('locations').upsert({
      'user_id': uid,
      'is_sharing': isSharing,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // --- Circles ----------------------------------------------------------

  Future<List<Circle>> fetchCircles() async {
    final c = client;
    if (c == null || userId == null) return const [];
    final rows = await c.from('circles').select().order('created_at');
    return (rows as List)
        .map((r) => Circle.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Circle> createCircle(String name) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) {
      throw StateError('Sign in to create a circle.');
    }
    final row = await c.rpc('create_circle', params: {
      'circle_name': name,
      'circle_type': 'permanent',
    });
    return Circle.fromJson(row);
  }

  Future<void> joinCircle(String inviteCode) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) {
      throw StateError('Sign in to join a circle.');
    }
    await c.rpc('join_circle', params: {
      'join_code': inviteCode.trim().toUpperCase(),
    });
  }

  Future<void> removeCircleMember({
    required String circleId,
    required String userId,
  }) async {
    final c = client;
    if (c == null || this.userId == null) {
      throw StateError('Sign in to manage circle members.');
    }
    await c
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<List<Place>> fetchPlaces() async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) return const [];
    final rows = await c.from('places').select().eq('user_id', uid).order('created_at');
    return (rows as List)
        .map((row) => Place.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Place> createPlace({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) throw StateError('Sign in to save places.');
    final row = await c.from('places').insert({
      'user_id': uid,
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'radius_m': radiusMeters,
    }).select().single();
    return Place.fromJson(row);
  }

  Future<void> deletePlace(String placeId) async {
    final c = client;
    if (c == null || userId == null) return;
    await c.from('places').delete().eq('id', placeId);
  }

  /// Realtime stream of member positions for a circle (MD section 59).
  Stream<List<LiveLocation>> watchCircleMembers(String circleId) async* {
    final c = client;
    if (c == null) {
      yield const [];
      return;
    }

    final members = await c
        .from('circle_members')
        .select('user_id, display_name')
        .eq('circle_id', circleId);
    final names = <String, String>{
      for (final row in members as List)
        row['user_id'] as String: (row['display_name'] as String?) ?? 'Member',
    };
    if (names.isEmpty) {
      yield const [];
      return;
    }

    yield* c.from('locations').stream(primaryKey: ['user_id']).map((rows) {
      final visible = rows.where((row) => names.containsKey(row['user_id']));
      return visible
          .map((row) => LiveLocation.fromJson({
                ...row,
                'display_name': names[row['user_id']],
              }))
          .toList();
    });
  }

  Future<void> sendSos({
    required String circleId,
    double? latitude,
    double? longitude,
    String message = 'Emergency! I need help.',
  }) async {
    final c = client;
    final uid = userId;
    if (c == null || uid == null) {
      throw StateError('Sign in to send an SOS alert.');
    }
    await c.from('sos_alerts').insert({
      'sender_id': uid,
      'circle_id': circleId,
      'lat': latitude,
      'lng': longitude,
      'message': message,
    });
  }

  Stream<SosAlert?> watchActiveSos(String circleId) {
    final c = client;
    if (c == null) return Stream.value(null);
    return c
        .from('sos_alerts')
        .stream(primaryKey: ['id'])
        .eq('circle_id', circleId)
        .eq('status', 'active')
        .map((rows) {
          if (rows.isEmpty) return null;
          final sorted = [...rows]
            ..sort((a, b) => (b['created_at'] as String)
                .compareTo(a['created_at'] as String));
          return SosAlert.fromJson(sorted.first);
        });
  }

}
