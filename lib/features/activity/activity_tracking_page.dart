import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/enums.dart';
import '../../data/models/journey_stats.dart';
import '../../shared/components.dart';
import '../map/map_tiles.dart';
import '../journey/tracking_controller.dart';
import 'activity_summary_page.dart';

class ActivityTrackingPage extends ConsumerStatefulWidget {
  const ActivityTrackingPage({super.key});

  @override
  ConsumerState<ActivityTrackingPage> createState() =>
      _ActivityTrackingPageState();
}

class _ActivityTrackingPageState extends ConsumerState<ActivityTrackingPage> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(trackingControllerProvider);
    final controller = ref.read(trackingControllerProvider.notifier);
    final s = state.stats ?? const JourneyStats();

    ref.listen(trackingControllerProvider, (prev, next) {
      final here = next.here;
      if (here != null && prev?.here != here) {
        _map.move(here, _map.camera.zoom < 15 ? 16 : _map.camera.zoom);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: state.here ?? const LatLng(0, 0),
                initialZoom: state.here == null ? 2 : 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                journeyTileLayer(),
                if (state.route.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: state.route,
                        strokeWidth: 6,
                        color: c.accent,
                      ),
                    ],
                  ),
                if (state.here != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: state.here!,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: c.shadowDark, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(
                        state.autoPaused
                            ? '${s.type.verb.toUpperCase()} · AUTO-PAUSED'
                            : state.phase == TrackingPhase.paused
                                ? '${s.type.verb.toUpperCase()} · PAUSED'
                                : s.type.verb.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                    _SignalChip(quality: state.signalQuality),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Panel(
              state: state,
              onPause: controller.pause,
              onResume: controller.resume,
              onFinish: () async {
                final journey = await controller.finish();
                if (!context.mounted || journey == null) return;
                Navigator.of(context).pushReplacement(
                  journeyRoute(ActivitySummaryPage(journey: journey)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final TrackingState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = state.stats ?? const JourneyStats();
    final paused = state.phase == TrackingPhase.paused;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      decoration: BoxDecoration(
        color: c.glassFillStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: c.shadowDark,
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.km(s.distanceMeters),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: c.onSurface,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          Text('KILOMETRES', style: TextStyle(
            color: c.onSurfaceMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontSize: 11,
          )),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: 'Time', value: Fmt.duration(s.elapsedSeconds)),
              _Stat(label: 'Pace', value: Fmt.pace(s.avgSpeed)),
              _Stat(label: 'Speed', value: Fmt.speed(s.currentSpeed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                label: 'Elevation',
                value: '+${s.elevationGain.round()} m',
              ),
              _Stat(label: 'Calories', value: '${s.calories.round()}'),
              _Stat(
                label: 'This km',
                value: s.currentSplitSpeed > 0
                    ? Fmt.pace(s.currentSplitSpeed)
                    : (s.lastSplitPace > 0
                        ? Fmt.paceFromSeconds(s.lastSplitPace)
                        : "--'--"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: paused ? 'Resume' : 'Pause',
                  icon: paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tone: NeoButtonTone.neutral,
                  onPressed: paused ? onResume : onPause,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  label: 'Finish',
                  icon: Icons.flag_rounded,
                  tone: NeoButtonTone.danger,
                  onPressed: onFinish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.quality});
  final SignalQuality quality;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (quality) {
      SignalQuality.good => c.online,
      SignalQuality.fair => c.drive,
      SignalQuality.poor => c.danger,
      SignalQuality.none => c.onSurfaceMuted,
    };
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            quality.label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.8,
              color: c.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: c.onSurfaceMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
