import 'package:flutter/material.dart';

import '../../shared/components.dart';

/// Explains why location is needed *before* the OS prompt (MD section 63).
/// Returns true if the user chose to continue.
Future<bool?> showLocationRationale(BuildContext context) {
  final c = context.colors;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(14),
      child: GlassSurface(
        radius: 28,
        blur: 24,
        strong: true,
        padding: const EdgeInsets.all(24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassSurface(
            radius: 20,
            blur: 8,
            padding: const EdgeInsets.all(16),
            child: Icon(Icons.location_on_rounded, color: c.accent, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            'Location access',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'KinPulse needs your location to record workouts and show your '
            'position to people you have chosen. You control sharing at any '
            'time, and you can stop it from the map.',
            style: TextStyle(color: c.onSurfaceMuted, height: 1.45),
          ),
          const SizedBox(height: 22),
          NeoButton(
            label: 'Continue',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          NeoButton(
            label: 'Not now',
            tone: NeoButtonTone.neutral,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      ),
    ),
  );
}
