import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/components.dart';
import '../shell/journey_shell.dart';
import 'login_page.dart';

/// Set when the user chooses to use Journey360 without an account.
final offlineEnteredProvider = StateProvider<bool>((ref) => false);

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authChangesProvider);
    final backend = ref.watch(backendEnabledProvider);
    final signedIn = ref.watch(authRepositoryProvider).session != null;
    final offline = ref.watch(offlineEnteredProvider);

    if ((backend && signedIn) || offline) {
      return const _ShellWithBanner();
    }
    return const LoginPage();
  }
}

class _ShellWithBanner extends ConsumerWidget {
  const _ShellWithBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final backend = ref.watch(backendEnabledProvider);
    final signedIn = ref.watch(authRepositoryProvider).session != null;
    final showBanner = !backend || !signedIn;

    return Stack(
      children: [
        const JourneyShell(),
        if (showBanner)
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: GlassSurface(
                radius: 18,
                blur: 18,
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        backend
                          ? 'Using KinPulse without an account. Sign in to '
                                'sync and use circles.'
                          : 'Offline mode - journeys save on this device.',
                        style: TextStyle(fontSize: 11.5, color: c.onSurface),
                      ),
                    ),
                    if (backend)
                      TextButton(
                        onPressed: () => ref
                            .read(offlineEnteredProvider.notifier)
                            .state = false,
                        child: const Text('Sign in'),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
