import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/components.dart';
import '../journey/tracking_controller.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tracking = ref.watch(trackingControllerProvider);
    final week = ref.watch(weekTotalsProvider);
    final latest = ref.watch(lastJourneyProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your edge', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text('Performance and protection, together.', style: TextStyle(color: c.onSurfaceMuted)),
                    ],
                  ),
                ),
                _VipBadge(color: c.accent),
              ],
            ),
            const SizedBox(height: 22),
            NeoCard(
              color: c.accent,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crash protection is active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('24/7 dispatch coverage is unlocked for your circle.', style: TextStyle(color: Colors.white70, height: 1.3)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('THIS WEEK'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Metric(value: '${(week.meters / 1000).toStringAsFixed(1)} km', label: 'Distance', icon: Icons.route_rounded, color: c.accent)),
                const SizedBox(width: 10),
                Expanded(child: _Metric(value: '${week.count}', label: 'Activities', icon: Icons.bolt_rounded, color: c.run)),
                const SizedBox(width: 10),
                Expanded(child: _Metric(value: _formatMinutes(week.seconds), label: 'Moving time', icon: Icons.timer_outlined, color: c.drive)),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('SEGMENT LEADERBOARD'),
            const SizedBox(height: 10),
            NeoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: const [
                  _RankRow(rank: '01', name: 'Riverside tempo', detail: '5:12 / km', delta: '-18s', highlighted: true),
                  Divider(height: 1),
                  _RankRow(rank: '02', name: 'North loop climb', detail: '2:48 / km', delta: '-06s'),
                  Divider(height: 1),
                  _RankRow(rank: '03', name: 'Canal sprint', detail: '4:36 / km', delta: '+04s'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('BODY SIGNAL'),
            const SizedBox(height: 10),
            NeoCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: .68, strokeWidth: 8, backgroundColor: c.accentSoft, color: c.accent),
                        Text('68', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.onSurface)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cardiovascular strain', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Moderate load. You have room for a quality session today.', style: TextStyle(color: c.onSurfaceMuted, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('LATEST ACTIVITY'),
            const SizedBox(height: 10),
            NeoCard(
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, color: c.accent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text(latest == null ? 'Start your first workout to build your baseline.' : latest.displayTitle, style: Theme.of(context).textTheme.titleMedium)),
                  if (tracking.isRecording) const Icon(Icons.fiber_manual_record_rounded, color: Colors.red, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMinutes(int seconds) {
    final minutes = seconds ~/ 60;
    return minutes > 59 ? '${minutes ~/ 60}h ${minutes % 60}m' : '${minutes}m';
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.stars_rounded, size: 16, color: color), const SizedBox(width: 5), Text('VIP', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))]),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon, required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => NeoCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 20), const SizedBox(height: 12), Text(value, style: TextStyle(color: context.colors.onSurface, fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 3), Text(label, style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 11))]),
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.detail, required this.delta, this.highlighted = false});
  final String rank;
  final String name;
  final String detail;
  final String delta;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [Text(rank, style: TextStyle(color: highlighted ? c.accent : c.onSurfaceMuted, fontWeight: FontWeight.w800)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(detail, style: TextStyle(color: c.onSurfaceMuted, fontSize: 12))])), Text(delta, style: TextStyle(color: delta.startsWith('-') ? c.online : c.onSurfaceMuted, fontWeight: FontWeight.w800, fontSize: 12))]),
    );
  }
}