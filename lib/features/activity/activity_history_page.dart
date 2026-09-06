import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/enums.dart';
import '../../data/models/journey.dart';
import '../../shared/components.dart';
import 'activity_summary_page.dart';

/// Unified journey history with type filters (MD sections 22, 29).
class ActivityHistoryPage extends ConsumerStatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  ConsumerState<ActivityHistoryPage> createState() =>
      _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends ConsumerState<ActivityHistoryPage> {
  JourneyType? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = ref.watch(journeyHistoryProvider);

    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Journey history'),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Chip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final t in JourneyType.values)
                    _Chip(
                      label: '${t.emoji} ${t.verb}',
                      selected: _filter == t,
                      onTap: () => setState(() => _filter = t),
                    ),
                ],
              ),
            ),
            Expanded(
              child: history.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(
                    'Could not load history',
                    style: TextStyle(color: c.onSurfaceMuted),
                  ),
                ),
                data: (all) {
                  final list = _filter == null
                      ? all
                      : all.where((j) => j.type == _filter).toList();
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: NeoEmptyState(
                        icon: Icons.timeline_rounded,
                        title: 'Nothing here yet',
                        message:
                            'Journeys you record will appear in this list.',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _Row(journey: list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: selected
              ? Glass.fill(c, radius: 14, tint: c.accent)
              : Glass.fill(c, radius: 14),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: selected ? c.accent : c.onSurfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.journey});
  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      onTap: () => context.pushJourney(
        ActivitySummaryPage(journey: journey),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(journey.type.icon, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.displayTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${Fmt.distance(journey.distanceMeters)}  ·  '
                  '${Fmt.durationShort(journey.durationSeconds)}  ·  '
                  '${Fmt.pace(journey.avgSpeed)}',
                  style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!journey.synced)
            Icon(Icons.cloud_off_rounded, size: 16, color: c.onSurfaceMuted),
        ],
      ),
    );
  }
}
