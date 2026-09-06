import 'package:flutter/material.dart';

import '../../shared/components.dart';

/// Placeholder for the vehicle-tracking module. The data model and database
/// table ship now; the driving UI and GPS-based event detection (MD sections
/// 24-29) arrive in the next milestone.
class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehicles',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('Drives, distance and driving events.',
                  style: TextStyle(color: c.onSurfaceMuted)),
              const SizedBox(height: 24),
              NeoEmptyState(
                icon: Icons.directions_car_rounded,
                title: 'Vehicle journeys arrive next',
                message:
                    'The next Journey360 update adds vehicle profiles, drive '
                    'recording, average / maximum speed and phone-GPS estimates '
                    'of hard braking and acceleration.\n\nJourney360 uses this '
                    "phone's GPS — it is not an OBD or telematics device.",
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: 0.5,
                child: NeoButton(
                  label: 'Add a vehicle',
                  icon: Icons.add,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
