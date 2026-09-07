import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'config/release_readiness.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Non-fatal in debug: loudly list anything that must be configured before a
  // production release. Release builds surface the same list in Settings.
  assert(() {
    final blockers = ReleaseReadiness.blockers;
    if (blockers.isNotEmpty) {
      debugPrint('[release-readiness] ${blockers.length} unmet requirement(s):');
      for (final b in blockers) {
        debugPrint('  - (${b.id}) ${b.summary} -> ${b.fix}');
      }
    }
    return true;
  }());

  if (AppConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
    } catch (_) {
      // Fall through to offline mode if initialization fails.
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const Journey360App(),
    ),
  );
}

class Journey360App extends ConsumerWidget {
  const Journey360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Journey360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}
