import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/components.dart';

class PlacesPage extends ConsumerWidget {
  const PlacesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final places = ref.watch(placesProvider);
    final backend = ref.watch(backendEnabledProvider);
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Saved places'),
      floatingActionButton: backend
          ? FloatingActionButton.extended(
              onPressed: () => _addPlace(context, ref),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add place'),
            )
          : null,
      body: SafeArea(
        child: !backend
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: NeoEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Connect an account to save places',
                  message: 'Saved places sync to your circle and power geofence alerts.',
                ),
              )
            : places.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text('Could not load places', style: TextStyle(color: c.onSurfaceMuted))),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: NeoEmptyState(
                          icon: Icons.place_outlined,
                          title: 'No saved places yet',
                          message: 'Add home, work, school, or any place your circle should know about.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final place = list[index];
                          return NeoCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.place_rounded, color: c.accent),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(place.name, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text('Geofence radius ${place.radiusMeters.round()} m', style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5)),
                                  ]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: c.danger,
                                  tooltip: 'Delete place',
                                  onPressed: () async {
                                    await ref.read(circleRepositoryProvider).deletePlace(place.id);
                                    ref.invalidate(placesProvider);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Future<void> _addPlace(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '150');
    final service = ref.read(locationServiceProvider);
    final position = await service.currentPosition();
    if (!context.mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location is not available.')));
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add saved place'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Name', hintText: 'Home, work, school')),
          const SizedBox(height: 12),
          TextField(controller: radiusController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Radius in metres')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !context.mounted || nameController.text.trim().isEmpty) return;
    final radius = double.tryParse(radiusController.text) ?? 150;
    try {
      await ref.read(circleRepositoryProvider).createPlace(
            name: nameController.text.trim(),
            latitude: position.latitude,
            longitude: position.longitude,
            radiusMeters: radius.clamp(50, 1000),
          );
      ref.invalidate(placesProvider);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save place: $error')));
    }
  }
}
