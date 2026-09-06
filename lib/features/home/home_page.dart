import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/enums.dart';
import '../../shared/components.dart';
import '../activity/activity_history_page.dart';
import '../activity/activity_summary_page.dart';
import '../activity/activity_tracking_page.dart';
import '../circles/circles_page.dart';
import '../journey/tracking_controller.dart';
import '../settings/settings_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tracking = ref.watch(trackingControllerProvider);
    final last = ref.watch(lastJourneyProvider);
    final today = ref.watch(todayTotalsProvider);
    final auth = ref.watch(authRepositoryProvider);
    final name = (auth.currentUser?.userMetadata?['full_name'] as String?)
            ?.split(' ')
            .first ??
        'traveller';
    final sharing = ref.watch(settingsControllerProvider).sharingMode.isOn;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(journeyHistoryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 116),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, $name',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Every journey. One place.',
                          style: TextStyle(color: c.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                  SharingPill(on: sharing),
                ],
              ),
              const SizedBox(height: 20),
              if (!tracking.isRecording) const _ResumeCard(),
              _HeroCard(state: tracking),
              const SizedBox(height: 16),
              const _WeekCard(),
              const SizedBox(height: 24),
              const NeoSectionHeader('Today'),
              Row(
                children: [
                  Expanded(
                    child: NeoMetricCard(
                      value: '${Fmt.km(today[JourneyType.running] ?? 0)} km',
                      label: 'Running',
                      accentColor: c.run,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoMetricCard(
                      value: '${Fmt.km(today[JourneyType.walking] ?? 0)} km',
                      label: 'Walking',
                      accentColor: c.walk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeoMetricCard(
                      value: '${Fmt.km(today[JourneyType.cycling] ?? 0)} km',
                      label: 'Cycling',
                      accentColor: c.cycle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoMetricCard(
                      value: '${Fmt.km(today[JourneyType.driving] ?? 0)} km',
                      label: 'Driving',
                      accentColor: c.drive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              NeoSectionHeader(
                'Recent',
                trailing: GestureDetector(
                  onTap: () =>
                      context.pushJourney(const ActivityHistoryPage()),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (last == null)
                NeoEmptyState(
                  icon: Icons.timeline_rounded,
                  title: 'No journeys yet',
                  message:
                      'Start a walk, run or ride from the Activity tab and it '
                      'will show up here.',
                )
              else
                NeoCard(
                  onTap: () =>
                      context.pushJourney(const ActivityHistoryPage()),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(last.type.icon, color: c.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              last.displayTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${Fmt.distance(last.distanceMeters)}  ·  '
                              '${Fmt.durationShort(last.durationSeconds)}',
                              style: TextStyle(color: c.onSurfaceMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.onSurfaceMuted),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const NeoSectionHeader('Circle'),
              const _CircleStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final snap = ref.watch(interruptedJourneyProvider);
    if (snap == null) return const SizedBox.shrink();
    final j = snap.journey;

    Future<void> resume() async {
      final ok = await ref
          .read(trackingControllerProvider.notifier)
          .resumeInterrupted();
      if (!context.mounted) return;
      if (ok) context.pushJourney(const ActivityTrackingPage());
    }

    Future<void> save() async {
      final saved = await ref
          .read(trackingControllerProvider.notifier)
          .finishInterrupted();
      if (!context.mounted || saved == null) return;
      context.pushJourney(ActivitySummaryPage(journey: saved));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeoCard(
        color: c.drive,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, color: c.drive),
                const SizedBox(width: 10),
                Text(
                  'Unfinished ${j.type.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Fmt.distance(j.distanceMeters)} recorded before Journey360 '
              'closed. Pick up where you left off, or save what you have.',
              style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    label: 'Resume',
                    icon: Icons.play_arrow_rounded,
                    onPressed: resume,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeoButton(
                    label: 'Save',
                    tone: NeoButtonTone.neutral,
                    onPressed: save,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref
                    .read(trackingControllerProvider.notifier)
                    .discardInterrupted(),
                child: const Text('Discard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final week = ref.watch(weekTotalsProvider);
    return NeoCard(
      blur: 10,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK',
                  style: TextStyle(
                    color: c.onSurfaceMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${Fmt.km(week.meters)} km',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          _MiniStat(label: 'Time', value: Fmt.durationShort(week.seconds)),
          const SizedBox(width: 18),
          _MiniStat(label: 'Journeys', value: '${week.count}'),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: c.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: c.onSurfaceMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});
  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = state.stats;
    final recording = state.isRecording && s != null;

    return NeoCard(
      padding: const EdgeInsets.all(22),
      color: recording ? c.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recording ? 'JOURNEY IN PROGRESS' : 'YOUR JOURNEY',
            style: TextStyle(
              color: recording ? Colors.white70 : c.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            recording
                ? '${Fmt.km(s.distanceMeters)} km'
                : "You're currently stationary",
            style: TextStyle(
              color: recording ? Colors.white : c.onSurface,
              fontSize: recording ? 40 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recording
                ? '${s.type.verb} · ${Fmt.duration(s.elapsedSeconds)}'
                : 'Head to the Activity tab to record a walk, run or ride.',
            style: TextStyle(
              color: recording ? Colors.white70 : c.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleStrip extends ConsumerWidget {
  const _CircleStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final backend = ref.watch(backendEnabledProvider);
    if (!backend) {
      return NeoEmptyState(
        icon: Icons.groups_outlined,
        title: 'Circles need a connected account',
        message:
            'Connect a Supabase project and sign in to create circles and see '
            'people you trust on the live map.',
      );
    }
    final circles = ref.watch(circlesProvider);
    return circles.when(
      loading: () => const NeoCard(
        child: Center(child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (_, _) => NeoEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load circles',
        message: 'Check your connection and pull to refresh.',
      ),
      data: (list) {
        if (list.isEmpty) {
          return NeoEmptyState(
            icon: Icons.group_add_outlined,
            title: 'No circles yet',
            message: 'Create a circle to share your location with family or '
                'friends.',
            action: NeoButton(
              label: 'Create a circle',
              expand: false,
              icon: Icons.add,
              onPressed: () => context.pushJourney(const CirclesPage()),
            ),
          );
        }
        return Column(
          children: [
            for (final circle in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeoCard(
                  onTap: () => context.pushJourney(const CirclesPage()),
                  child: Row(
                    children: [
                      NeoAvatar(name: circle.name, radius: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              circle.name,
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${circle.memberCount} member'
                              '${circle.memberCount == 1 ? '' : 's'}',
                              style: TextStyle(color: c.onSurfaceMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.onSurfaceMuted),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
