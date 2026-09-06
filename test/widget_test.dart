import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journey_360/core/providers.dart';
import 'package:journey_360/features/settings/settings_controller.dart';
import 'package:journey_360/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _bootApp() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const Journey360App(),
  );
}

void main() {
  testWidgets('boots to the Journey360 sign-in screen offline', (tester) async {
    await tester.pumpWidget(await _bootApp());
    await tester.pump();

    expect(find.text('Journey360'), findsOneWidget);
    expect(find.text('Safety for your circle. Power for your next effort.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('entering offline mode reveals the three-mode shell', (tester) async {
    await tester.pumpWidget(await _bootApp());
    await tester.pump();

    final getStarted = find.text('Get started');
    await tester.ensureVisible(getStarted);
    await tester.pump();
    await tester.tap(getStarted);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // The floating glass nav shows the three Journey360 modes.
    for (final icon in const [
      Icons.shield_rounded, // Circle, selected
      Icons.bolt_outlined,
      Icons.insights_outlined,
    ]) {
      expect(find.byIcon(icon), findsWidgets, reason: 'missing $icon nav item');
    }
    expect(find.text('Circle'), findsOneWidget);
    expect(find.textContaining('Search places'), findsWidgets);
  });

  test('settings controller persists the theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    await container
        .read(settingsControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // A fresh container reads the persisted value back.
    final reopened = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(themeModeProvider), ThemeMode.dark);
  });
}
