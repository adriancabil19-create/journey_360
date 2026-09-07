import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../config/app_config.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/circle.dart';
import '../../data/models/enums.dart';
import '../../shared/components.dart';
import '../circles/circle_detail_page.dart';
import 'settings_controller.dart';

class SmartNotificationsPage extends ConsumerWidget {
  const SmartNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return _FeatureScaffold(
      title: 'Smart Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoCard(
            icon: Icons.notifications_active_outlined,
            title: 'Stay informed, not interrupted',
            message: 'Choose which Circle and Journey events should reach you. Emergency SOS and crash alerts always remain available.',
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Alerts'),
          _ToggleRow(title: 'Low battery notifications', subtitle: 'Know when a member drops below 10%', icon: Icons.battery_alert_outlined, value: settings.lowBatteryAlerts, onChanged: controller.setLowBatteryAlerts),
          _ToggleRow(title: 'Safe drive notifications', subtitle: 'Receive completed-drive summaries from your Circle', icon: Icons.directions_car_outlined, value: settings.safeDriveAlerts, onChanged: controller.setSafeDriveAlerts),
          _ToggleRow(title: 'Place notifications', subtitle: 'Get notified when members arrive or leave saved places', icon: Icons.place_outlined, value: settings.placeAlerts, onChanged: controller.setPlaceAlerts),
          _ToggleRow(title: 'Social notifications', subtitle: 'Updates and reactions from your Circle', icon: Icons.favorite_border_rounded, value: settings.socialAlerts, onChanged: controller.setSocialAlerts),
          const SizedBox(height: 20),
          const _SectionTitle('Emergency'),
          const _StaticStatusRow(icon: Icons.warning_amber_rounded, title: 'Crash and SOS alerts', subtitle: 'Always enabled for safety', status: 'ACTIVE'),
        ],
      ),
    );
  }
}

class LocationSharingPage extends ConsumerWidget {
  const LocationSharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final circles = ref.watch(circlesProvider).valueOrNull ?? const [];
    return _FeatureScaffold(
      title: 'Location Sharing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoCard(icon: Icons.my_location_rounded, title: 'Your location sharing', message: 'Your location is only sent while sharing is on. You control the audience below.'),
          const SizedBox(height: 20),
          const _SectionTitle('Your location'),
          _ChoiceCard<SharingMode>(
            value: settings.sharingMode,
            options: const {SharingMode.everyone: 'Everyone in my Circles', SharingMode.selected: 'Selected people', SharingMode.nobody: 'Nobody'},
            onChanged: controller.setSharingMode,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Circle status'),
          if (circles.isEmpty)
            const _StaticStatusRow(icon: Icons.group_outlined, title: 'No Circles yet', subtitle: 'Create or join a Circle to share location', status: '')
          else
            for (final circle in circles)
              _StaticStatusRow(icon: Icons.group_rounded, title: circle.name, subtitle: 'Location sharing follows your setting', status: settings.sharingMode.isOn ? 'ON' : 'OFF'),
        ],
      ),
    );
  }
}

class ActivitySharingPage extends ConsumerWidget {
  const ActivitySharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return _FeatureScaffold(
      title: 'Activity Sharing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoCard(icon: Icons.phone_android_rounded, title: 'Activity Sharing', message: 'Journey360 can share the activity state of your phone and workouts with people in your selected Circle.'),
          const SizedBox(height: 20),
          const _SectionTitle('Your activity sharing'),
          _ToggleRow(title: 'Share activity status', subtitle: 'Let your Circle see when you are moving or working out', icon: Icons.directions_run_rounded, value: settings.journeyAlerts, onChanged: controller.setJourneyAlerts),
          const SizedBox(height: 20),
          const _SectionTitle('Completed activity visibility'),
          _ChoiceCard<JourneyVisibility>(
            value: settings.defaultVisibility,
            options: {for (final visibility in JourneyVisibility.values) visibility: visibility.label},
            onChanged: controller.setDefaultVisibility,
          ),
        ],
      ),
    );
  }
}

class CircleManagementPage extends ConsumerWidget {
  const CircleManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(circlesProvider);
    return _FeatureScaffold(
      title: 'Circle Management',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoCard(icon: Icons.groups_rounded, title: 'Manage your Circles', message: 'Each Circle is a separate group. Changes here apply only to the Circle you select.'),
          const SizedBox(height: 18),
          NeoButton(label: 'Create new Circle', icon: Icons.add_rounded, onPressed: () => _createCircle(context, ref)),
          const SizedBox(height: 10),
          NeoButton(label: 'Join with invite code', icon: Icons.key_rounded, tone: NeoButtonTone.neutral, onPressed: () => _joinCircle(context, ref)),
          const SizedBox(height: 22),
          const _SectionTitle('Your Circles'),
          circles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load Circles: $error'),
            data: (items) => items.isEmpty
                ? const _StaticStatusRow(icon: Icons.group_outlined, title: 'No Circles yet', subtitle: 'Create your first group above', status: '')
                : Column(children: [for (final circle in items) _CircleManagementRow(circle: circle)]),
          ),
        ],
      ),
    );
  }

  Future<void> _createCircle(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Create Circle'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Family, friends, team')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create'))]));
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      final circle = await ref.read(circleRepositoryProvider).create(name);
      ref.invalidate(circlesProvider);
      if (context.mounted) _showInvite(context, circle.inviteCode);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create Circle: $error')));
    }
  }

  Future<void> _joinCircle(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Join Circle'), content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Invite code')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Join'))]));
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      await ref.read(circleRepositoryProvider).join(code);
      ref.invalidate(circlesProvider);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join Circle: $error')));
    }
  }

  void _showInvite(BuildContext context, String code) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Invite Code'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Share this code with the people you want in your Circle.'), const SizedBox(height: 18), SelectableText(code, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: context.colors.accent, letterSpacing: 3))]), actions: [TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: code)); Navigator.pop(context); }, child: const Text('Copy code'))]));
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final businessDetails = [
      AppConfig.businessName,
      AppConfig.businessAddress,
      AppConfig.supportEmail,
    ].where((value) => value.isNotEmpty).join('\n');
    return _FeatureScaffold(
      title: 'About Journey360',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoCard(icon: Icons.explore_rounded, title: 'Journey360', message: 'Circle safety and athletic performance in one app.'),
          const SizedBox(height: 20),
          const _SectionTitle('What Journey360 does'),
          const _BodyText('Journey360 helps you stay connected to the people you choose while you walk, run, cycle, drive, and explore. Location sharing is controlled by you and protected by Supabase row-level security.'),
          const SizedBox(height: 18),
          const _SectionTitle('Business details'),
          _BodyText(businessDetails.isEmpty ? 'Business identity and support contact are not configured for this build.' : businessDetails),
          const SizedBox(height: 18),
          const _SectionTitle('Version'),
          const _BodyText('Journey360 1.0.0'),
          const SizedBox(height: 18),
          const _SectionTitle('Open source services and media'),
          const _BodyText('Maps use OpenStreetMap data and display attribution. This build contains no bundled stock or third-party marketing images. User-provided profile images are fetched only from their supplied URLs. GPS accuracy and background behavior depend on your device and operating system.'),
        ],
      ),
    );
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) => _FeatureScaffold(title: 'Terms of Use', child: const _LegalContent(title: 'Journey360 Terms of Use', sections: {'Using Journey360': 'You may use Journey360 to share your own location and activity with people you choose. Do not use the service to track someone without their knowledge or consent.', 'Safety limitations': 'Journey360 is not a substitute for emergency services. GPS, mobile networks, sensors, and background execution can be unavailable or inaccurate. Call local emergency services when immediate help is needed.', 'Accounts and access': 'Keep your account credentials private. You are responsible for activity performed through your account.', 'Acceptable use': 'Do not abuse, reverse engineer, disrupt, or use Journey360 for unlawful surveillance, harassment, or unsafe conduct.', 'Changes': 'We may update these terms as the service evolves. Continued use after an update means you accept the revised terms.'}));
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => _FeatureScaffold(title: 'Privacy Center', child: _LegalContent(title: 'Journey360 Privacy Notice', sections: {
    'Location data': 'When sharing is enabled, Journey360 may transmit your current location, accuracy, speed, battery level, and activity state to the configured Supabase project for the people authorized by your Circle. Location is sensitive personal information and should only be shared with people you trust.',
    'Activity data': 'Completed activities may include routes, distance, duration, pace, elevation, and calories. Visibility is controlled by your activity sharing setting.',
    'Third parties and retention': 'Supabase hosts account and synchronized data for the deployment owner. OpenStreetMap tile servers may receive network requests needed to display the map. Journey360 currently has no advertising SDK, analytics SDK, tracking pixel, or embedded third-party media. Data is retained while needed to provide the service or until you request deletion, subject to backups and legal obligations.',
    'Your choices': 'You can stop sharing, remove saved places, leave Circles, delete local activity data, revoke location permission in device settings, or request account and synchronized-data deletion from the configured privacy contact.',
    'Security and children': 'Access is restricted by Supabase authentication and row-level security policies. No system can guarantee absolute security. Do not use the service for children without the required parental or guardian permissions.',
    'Contact': AppConfig.privacyEmail.isEmpty ? 'A privacy contact has not been configured for this deployment. The operator must configure PRIVACY_EMAIL before production release.' : 'Privacy contact: ${AppConfig.privacyEmail}',
  }));
}

class CookiePolicyPage extends StatelessWidget {
  const CookiePolicyPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureScaffold(title: 'Cookie Policy', child: _LegalContent(title: 'Journey360 Cookie Policy', sections: {
    'Current use': 'Journey360 does not currently use advertising cookies, analytics cookies, tracking pixels, fingerprinting, or third-party advertising embeds. The web build may use browser storage for app preferences and an interrupted journey; this is necessary for requested functionality rather than behavioral advertising.',
    'Third-party services': 'Supabase may use strictly necessary session mechanisms for authentication. OpenStreetMap tile requests are made when a map is displayed. Review those providers\' policies before production launch and document any additional SDK or embed that is enabled.',
    'Your choices': 'You can clear browser storage or sign out to remove local session state. If optional analytics or marketing tracking is added later, it must remain disabled until you provide informed consent and a way to withdraw it.',
  }));
}

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureScaffold(title: 'Refund Policy', child: _LegalContent(title: 'Journey360 Refund Policy', sections: {
    'No paid service yet': 'Journey360 does not currently process payments, subscriptions, or in-app purchases. No refund process is active because payment is bypassed.',
    'Future changes': 'If paid features are introduced, pricing, billing terms, cancellation, renewal, statutory consumer rights, and refund instructions will be published before payment is enabled. No payment should be requested under this version of the app.',
  }));
}

class _FeatureScaffold extends StatelessWidget {
  const _FeatureScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => NeoScaffold(title: title, body: child);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => NeoCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: context.colors.accentSoft, shape: BoxShape.circle), child: Icon(icon, color: context.colors.accent, size: 26)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text(message, style: TextStyle(color: context.colors.onSurfaceMuted, height: 1.4))]))]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: TextStyle(color: context.colors.onSurfaceMuted, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.1)));
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: context.colors.onSurfaceMuted, height: 1.55, fontSize: 14));
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeoCard(
          child: Row(
            children: [
              Icon(icon, color: context.colors.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.colors.onSurface, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
}

class _StaticStatusRow extends StatelessWidget {
  const _StaticStatusRow({required this.icon, required this.title, required this.subtitle, required this.status});
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => NeoCard(child: Row(children: [Icon(icon, color: context.colors.accent, size: 24), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: context.colors.onSurface, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12))])), if (status.isNotEmpty) Text(status, style: TextStyle(color: context.colors.online, fontWeight: FontWeight.w800, fontSize: 11))]));
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => NeoCard(
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          child: Column(
            children: [
              for (final entry in options.entries)
                RadioListTile<T>(value: entry.key, title: Text(entry.value)),
            ],
          ),
        ),
      );
}

class _CircleManagementRow extends StatelessWidget {
  const _CircleManagementRow({required this.circle});
  final Circle circle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeoCard(
          onTap: () => context.pushJourney(CircleDetailPage(circle: circle)),
          child: Row(
            children: [
              NeoAvatar(name: circle.name, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(circle.name, style: Theme.of(context).textTheme.titleMedium),
                    Text('Invite code ${circle.inviteCode}', style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceMuted),
            ],
          ),
        ),
      );
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.title, required this.sections});
  final String title;
  final Map<String, String> sections;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text('Last updated September 7, 2026', style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12)), const SizedBox(height: 22), for (final section in sections.entries) Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(section.key, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(section.value, style: TextStyle(color: context.colors.onSurfaceMuted, height: 1.5))]))]);
}
