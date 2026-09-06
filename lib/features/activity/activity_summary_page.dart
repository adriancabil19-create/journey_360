import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/journey.dart';
import '../../shared/components.dart';
import '../map/map_tiles.dart';

/// Post-journey summary with the full route on a map (MD section 21).
class ActivitySummaryPage extends StatelessWidget {
  const ActivitySummaryPage({super.key, required this.journey});

  final Journey journey;

  LatLngBounds? get _bounds {
    if (journey.polyline.length < 2) return null;
    return LatLngBounds.fromPoints(journey.polyline);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final route = journey.polyline;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${journey.type.label} complete'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
                .popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              height: 240,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: c.shadowDark, blurRadius: 16),
                ],
              ),
              child: route.length < 2
                  ? Container(
                      color: c.surfaceLow,
                      alignment: Alignment.center,
                      child: Text(
                        'No GPS route was recorded',
                        style: TextStyle(color: c.onSurfaceMuted),
                      ),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCameraFit: _bounds == null
                            ? null
                            : CameraFit.bounds(
                                bounds: _bounds!,
                                padding: const EdgeInsets.all(32),
                              ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        journeyTileLayer(),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route,
                              strokeWidth: 5,
                              color: c.accent,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            _dot(route.first, c.online),
                            _dot(route.last, c.danger),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            _BigStat(
              label: 'Distance',
              value: '${Fmt.km(journey.distanceMeters)} km',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NeoMetricCard(
                    value: Fmt.duration(journey.durationSeconds),
                    label: 'Time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoMetricCard(
                    value: Fmt.pace(journey.avgSpeed),
                    label: 'Avg pace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NeoMetricCard(
                    value: Fmt.speed(journey.avgSpeed),
                    label: 'Avg speed',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoMetricCard(
                    value: Fmt.speed(journey.maxSpeed),
                    label: 'Max speed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NeoMetricCard(
                    value: '+${journey.elevationGain.round()} m',
                    label: 'Elevation',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoMetricCard(
                    value: '${journey.calories.round()}',
                    label: 'Calories',
                  ),
                ),
              ],
            ),
            if (journey.splits.isNotEmpty) ...[
              const SizedBox(height: 22),
              const NeoSectionHeader('Kilometre splits'),
              _Splits(journey: journey),
            ],
            const SizedBox(height: 16),
            Text(
              journey.synced
                  ? 'Saved to your account.'
                  : 'Saved on this device. It will sync when a connected '
                      'account is available.',
              style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Marker _dot(LatLng point, Color color) => Marker(
        point: point,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      );
}

class _Splits extends StatelessWidget {
  const _Splits({required this.journey});
  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final splits = journey.splits;
    final fastest = splits
        .map((s) => s.paceSecondsPerKm)
        .where((p) => p > 0)
        .fold<double>(double.infinity, (a, b) => b < a ? b : a);
    final slowest = splits
        .map((s) => s.paceSecondsPerKm)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return NeoCard(
      blur: 10,
      child: Column(
        children: [
          for (final split in splits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${split.index}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: c.onSurfaceMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: slowest > 0
                            ? (split.paceSecondsPerKm / slowest).clamp(0.08, 1.0)
                            : 0.5,
                        backgroundColor: c.glassBorder,
                        color: split.paceSecondsPerKm == fastest
                            ? c.online
                            : c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Fmt.paceFromSeconds(split.paceSecondsPerKm)
                        .replaceAll(' /km', ''),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: c.onSurface,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
    );
  }
}
