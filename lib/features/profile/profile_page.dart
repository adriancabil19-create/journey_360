import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/enums.dart';
import '../../shared/components.dart';
import '../activity/activity_history_page.dart';
import '../circles/circles_page.dart';
import '../settings/settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final auth = ref.watch(authRepositoryProvider);
    final totals = ref.watch(lifetimeTotalsProvider);
    final history = ref.watch(journeyHistoryProvider).valueOrNull ?? const [];
    final name =
        (auth.currentUser?.userMetadata?['full_name'] as String?) ?? 'You';
    final email = auth.currentUser?.email;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 116),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Profile',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                NeoIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: () => context.pushJourney(const SettingsPage()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NeoCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  NeoAvatar(name: name, radius: 40),
                  const SizedBox(height: 14),
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    email ?? 'KinPulse member',
                    style: TextStyle(color: c.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NeoMetricCard(
                    value: '${Fmt.km(totals[JourneyType.running] ?? 0)} km',
                    label: 'Running',
                    accentColor: c.run,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoMetricCard(
                    value: '${Fmt.km(totals[JourneyType.walking] ?? 0)} km',
                    label: 'Walking',
                    accentColor: c.walk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoMetricCard(
                    value: '${Fmt.km(totals[JourneyType.driving] ?? 0)} km',
                    label: 'Driving',
                    accentColor: c.drive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const NeoSectionHeader('Your account'),
            _Row(
              icon: Icons.timeline_rounded,
              title: 'Activities',
              subtitle: '${history.length} recorded',
              onTap: () => context.pushJourney(const ActivityHistoryPage()),
            ),
            _Row(
              icon: Icons.insights_rounded,
              title: 'Statistics',
              subtitle: 'Lifetime totals and records',
              onTap: () => context.pushJourney(const _StatsPage()),
            ),
            _Row(
              icon: Icons.groups_rounded,
              title: 'Circles',
              subtitle: 'People you share location with',
              onTap: () => context.pushJourney(const CirclesPage()),
            ),
            _Row(
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Privacy, tracking, appearance',
              onTap: () => context.pushJourney(const SettingsPage()),
            ),
            const SizedBox(height: 16),
            if (auth.isEnabled && auth.currentUser != null)
              NeoButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                tone: NeoButtonTone.neutral,
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle,
                      style: TextStyle(
                          color: c.onSurfaceMuted, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _StatsPage extends ConsumerWidget {
  const _StatsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final history = ref.watch(journeyHistoryProvider).valueOrNull ?? const [];
    final totalDistance =
        history.fold<double>(0, (sum, j) => sum + j.distanceMeters);
    final totalSeconds =
        history.fold<int>(0, (sum, j) => sum + j.durationSeconds);
    final longest = history.isEmpty
        ? 0.0
        : history
            .map((j) => j.distanceMeters)
            .reduce((a, b) => a > b ? a : b);
    final fastestPace = history
        .where((j) => j.avgSpeed > 0.3)
        .fold<double>(0, (best, j) => j.avgSpeed > best ? j.avgSpeed : best);

    return NeoScaffold(
      title: 'Statistics',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: NeoStatCard(
                  icon: Icons.route_rounded,
                  value: '${Fmt.km(totalDistance)} km',
                  label: 'Total distance',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoStatCard(
                  icon: Icons.flag_rounded,
                  value: '${history.length}',
                  label: 'Journeys',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeoStatCard(
                  icon: Icons.timer_outlined,
                  value: Fmt.durationShort(totalSeconds),
                  label: 'Active time',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoStatCard(
                  icon: Icons.trending_up_rounded,
                  value: '${Fmt.km(longest)} km',
                  label: 'Longest',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NeoStatCard(
            icon: Icons.bolt_rounded,
            value: fastestPace > 0 ? Fmt.pace(fastestPace) : "--'--",
            label: 'Fastest average pace',
          ),
          const SizedBox(height: 16),
          Text(
            'Charts and weekly breakdowns are coming in a future update.',
            style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
