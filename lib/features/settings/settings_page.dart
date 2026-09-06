import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/enums.dart';
import '../../shared/components.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final auth = ref.watch(authRepositoryProvider);

    return NeoScaffold(
      title: 'Settings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NeoSectionHeader('Appearance'),
          _Segmented<ThemeMode>(
            value: settings.themeMode,
            options: const {
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
              ThemeMode.system: 'System',
            },
            onChanged: ctrl.setThemeMode,
          ),
          const SizedBox(height: 22),
          const NeoSectionHeader('Privacy'),
          _Tile(
            label: 'Location sharing',
            child: _Segmented<SharingMode>(
              value: settings.sharingMode,
              options: {
                for (final m in SharingMode.values)
                  m: m == SharingMode.everyone
                      ? 'Everyone'
                      : m == SharingMode.selected
                          ? 'Selected'
                          : 'Nobody',
              },
              onChanged: ctrl.setSharingMode,
            ),
          ),
          _Tile(
            label: 'Default activity visibility',
            child: _Segmented<JourneyVisibility>(
              value: settings.defaultVisibility,
              options: {
                for (final v in JourneyVisibility.values) v: v.label,
              },
              onChanged: ctrl.setDefaultVisibility,
            ),
          ),
          const SizedBox(height: 22),
          const NeoSectionHeader('Tracking'),
          _Tile(
            label: 'GPS profile',
            child: _Segmented<TrackingProfile>(
              value: settings.trackingProfile,
              options: {
                TrackingProfile.batterySaver: 'Saver',
                TrackingProfile.balanced: 'Balanced',
                TrackingProfile.highAccuracy: 'Accurate',
              },
              onChanged: ctrl.setTrackingProfile,
            ),
          ),
          NeoToggle(
            title: 'Auto-pause when stopped',
            subtitle: 'Pause the timer automatically while you are not moving',
            icon: Icons.motion_photos_pause_outlined,
            value: settings.autoPauseEnabled,
            onChanged: ctrl.setAutoPause,
          ),
          const SizedBox(height: 22),
          const NeoSectionHeader('Notifications'),
          NeoToggle(
            title: 'Journey alerts',
            icon: Icons.route_outlined,
            value: settings.journeyAlerts,
            onChanged: ctrl.setJourneyAlerts,
          ),
          const SizedBox(height: 10),
          NeoToggle(
            title: 'Circle alerts',
            icon: Icons.groups_outlined,
            value: settings.circleAlerts,
            onChanged: ctrl.setCircleAlerts,
          ),
          const SizedBox(height: 10),
          NeoToggle(
            title: 'Social alerts',
            icon: Icons.favorite_outline,
            value: settings.socialAlerts,
            onChanged: ctrl.setSocialAlerts,
          ),
          const SizedBox(height: 22),
          const NeoSectionHeader('Account'),
          NeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Email', auth.currentUser?.email ?? 'Not signed in'),
                const SizedBox(height: 8),
                _kv(
                  context,
                  'Backend',
                  ref.watch(backendEnabledProvider)
                      ? 'Supabase connected'
                      : 'Offline mode',
                ),
                if (auth.isEnabled && auth.currentUser != null) ...[
                  const SizedBox(height: 14),
                  NeoButton(
                    label: 'Send password reset email',
                    tone: NeoButtonTone.neutral,
                    onPressed: () async {
                      final email = auth.currentUser?.email;
                      if (email == null) return;
                      await ref
                          .read(authRepositoryProvider)
                          .sendPasswordReset(email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Password reset email sent.')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Journey360 records GPS from this device. Background tracking is '
            'limited by each platform: the web has none, Android needs a '
            'foreground service, and iOS throttles background updates.',
            style: TextStyle(color: c.onSurfaceMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: c.onSurfaceMuted)),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: Glass.inset(c, radius: 16),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: entry.key == value
                      ? BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        )
                      : const BoxDecoration(),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: entry.key == value
                          ? Colors.white
                          : c.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
