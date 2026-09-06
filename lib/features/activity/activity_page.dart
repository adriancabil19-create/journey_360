import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/page_transition.dart';
import '../../data/models/enums.dart';
import '../../shared/components.dart';
import '../journey/tracking_controller.dart';
import 'activity_history_page.dart';
import 'activity_tracking_page.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  JourneyType _type = JourneyType.running;

  static const _choices = [
    JourneyType.running,
    JourneyType.walking,
    JourneyType.cycling,
  ];

  Future<void> _start() async {
    final ok = await ref.read(trackingControllerProvider.notifier).start(_type);
    if (!mounted) return;
    if (ok) {
      context.pushJourney(const ActivityTrackingPage());
    } else {
      final err = ref.read(trackingControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not start tracking.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(trackingControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activity',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  NeoIconButton(
                    icon: Icons.history_rounded,
                    tooltip: 'History',
                    onTap: () =>
                        context.pushJourney(const ActivityHistoryPage()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'What are you doing?',
                style: TextStyle(color: c.onSurfaceMuted),
              ),
              const SizedBox(height: 20),
              if (state.isRecording)
                NeoCard(
                  color: c.accent,
                  onTap: () =>
                      context.pushJourney(const ActivityTrackingPage()),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Journey in progress — tap to open',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                )
              else ...[
                for (final t in _choices) ...[
                  _TypeTile(
                    type: t,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                _ReadyCard(type: _type, onStart: _start),
              ],
              const SizedBox(height: 16),
              Text(
                'Journey360 records GPS from this device. Accuracy depends on '
                'your phone and surroundings.',
                style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final JourneyType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      onTap: onTap,
      color: selected ? c.accentSoft : null,
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              type.verb,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: selected ? c.accent : c.onSurface,
              ),
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? c.accent : c.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.type, required this.onStart});
  final JourneyType type;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'READY',
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '00:00',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: c.onSurface,
              letterSpacing: -1,
            ),
          ),
          Text('0.00 km', style: TextStyle(color: c.onSurfaceMuted)),
          const SizedBox(height: 20),
          NeoButton(
            label: 'Start ${type.label.toLowerCase()}',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
