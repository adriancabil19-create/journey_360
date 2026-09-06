import 'package:flutter_test/flutter_test.dart';
import 'package:journey_360/data/models/enums.dart';
import 'package:journey_360/features/journey/journey_recorder.dart';

LocationSample sample(
  double lat,
  double lng,
  DateTime t, {
  double? accuracy,
  double? altitude,
}) =>
    LocationSample(
      latitude: lat,
      longitude: lng,
      timestamp: t,
      accuracy: accuracy ?? 5,
      altitude: altitude,
    );

void main() {
  final start = DateTime(2026, 1, 1, 8);

  group('JourneyRecorder distance', () {
    test('accumulates geodesic distance between fixes', () {
      final rec = JourneyRecorder(type: JourneyType.running, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start));
      // ~111 m east at this latitude is roughly 0.001 deg longitude.
      rec.add(sample(10.3157, 123.88640, start.add(const Duration(seconds: 30))));
      final d = rec.stats.distanceMeters;
      expect(d, greaterThan(90));
      expect(d, lessThan(130));
    });

    test('does not add distance from a single point', () {
      final rec = JourneyRecorder(type: JourneyType.walking, startedAt: start);
      rec.add(sample(1, 1, start));
      expect(rec.stats.distanceMeters, 0);
      expect(rec.pointCount, 1);
    });
  });

  group('JourneyRecorder filtering', () {
    test('rejects fixes with poor accuracy', () {
      final rec = JourneyRecorder(type: JourneyType.running, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start));
      final accepted = rec.add(sample(
        10.3160,
        123.8860,
        start.add(const Duration(seconds: 10)),
        accuracy: 120,
      ));
      expect(accepted, isFalse);
      expect(rec.pointCount, 1);
    });

    test('rejects an implausible GPS jump', () {
      final rec = JourneyRecorder(type: JourneyType.walking, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start));
      // ~1 km in 2 seconds -> 500 m/s, impossible for walking.
      final accepted = rec.add(sample(
        10.3247,
        123.8854,
        start.add(const Duration(seconds: 2)),
      ));
      expect(accepted, isFalse);
      expect(rec.stats.distanceMeters, 0);
    });
  });

  group('JourneyRecorder stats', () {
    test('pause stops moving time from advancing', () {
      final rec = JourneyRecorder(type: JourneyType.running, startedAt: start);
      rec.tick(start);
      rec.tick(start.add(const Duration(seconds: 5)));
      rec.pause();
      rec.tick(start.add(const Duration(seconds: 20)));
      rec.resume();
      expect(rec.stats.movingSeconds, lessThanOrEqualTo(6));
    });

    test('finish produces a journey with route + summary', () {
      final rec = JourneyRecorder(type: JourneyType.cycling, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start));
      rec.add(sample(10.3157, 123.8874, start.add(const Duration(seconds: 40))));
      rec.tick(start.add(const Duration(seconds: 40)));
      final journey = rec.finish();
      expect(journey.type, JourneyType.cycling);
      expect(journey.route.length, 2);
      expect(journey.distanceMeters, greaterThan(150));
      expect(journey.endedAt, isNotNull);
      expect(journey.startLat, closeTo(10.3157, 0.0001));
    });

    test('closes a kilometre split once 1 km is passed', () {
      final rec = JourneyRecorder(type: JourneyType.running, startedAt: start);
      var t = start;
      // Walk east in ~50 m hops (0.00045 deg lng ~ 49 m here) for ~1.2 km.
      var lng = 123.8854;
      rec.add(sample(10.3157, lng, t));
      for (var i = 0; i < 26; i++) {
        t = t.add(const Duration(seconds: 8));
        lng += 0.00045;
        rec.tick(t);
        rec.add(sample(10.3157, lng, t));
      }
      expect(rec.splits, isNotEmpty);
      expect(rec.splits.first.index, 1);
      expect(rec.splits.first.paceSecondsPerKm, greaterThan(0));
    });

    test('fromJourney rebuilds distance and route from a snapshot', () {
      final rec = JourneyRecorder(type: JourneyType.cycling, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start));
      rec.add(sample(10.3157, 123.8894, start.add(const Duration(seconds: 60))));
      rec.tick(start.add(const Duration(seconds: 60)));
      final snapshot = rec.snapshot();
      expect(snapshot.endedAt, isNull);

      final restored = JourneyRecorder.fromJourney(snapshot);
      expect(restored.id, rec.id);
      expect(restored.points.length, rec.points.length);
      expect(
        restored.stats.distanceMeters,
        closeTo(rec.stats.distanceMeters, 1),
      );
    });

    test('elevation gain only counts ascents', () {
      final rec = JourneyRecorder(type: JourneyType.running, startedAt: start);
      rec.add(sample(10.3157, 123.8854, start, altitude: 10));
      rec.add(sample(10.3158, 123.8855, start.add(const Duration(seconds: 20)),
          altitude: 25));
      rec.add(sample(10.3159, 123.8856, start.add(const Duration(seconds: 40)),
          altitude: 15));
      expect(rec.stats.elevationGain, closeTo(15, 1));
    });
  });
}
