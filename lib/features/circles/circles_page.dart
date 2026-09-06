import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/page_transition.dart';
import '../../shared/components.dart';
import 'circle_detail_page.dart';

class CirclesPage extends ConsumerWidget {
  const CirclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendEnabledProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Circles',
        actions: [
          if (backend)
            IconButton(
              icon: const Icon(Icons.group_add_outlined),
              onPressed: () => _joinDialog(context, ref),
              tooltip: 'Join with code',
            ),
        ],
      ),
      floatingActionButton: backend
          ? FloatingActionButton.extended(
              onPressed: () => _createDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New circle'),
            )
          : null,
      body: SafeArea(
        child: !backend
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: NeoEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Connect an account to use circles',
                  message:
                      'Circles use a Supabase project for realtime location '
                      'sharing. Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, '
                      'then sign in.',
                ),
              )
            : _CircleList(),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New circle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Family, Running group…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(circleRepositoryProvider).create(name);
      ref.invalidate(circlesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _joinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a circle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Invite code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref.read(circleRepositoryProvider).join(code);
      ref.invalidate(circlesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _CircleList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final circles = ref.watch(circlesProvider);
    return circles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text('Could not load circles',
            style: TextStyle(color: c.onSurfaceMuted)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: NeoEmptyState(
              icon: Icons.group_add_outlined,
              title: 'No circles yet',
              message: 'Tap "New circle" to create your first one.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final circle = list[i];
            return NeoCard(
              onTap: () => context.pushJourney(
                CircleDetailPage(circle: circle),
              ),
              child: Row(
                children: [
                  NeoAvatar(name: circle.name, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(circle.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'Invite code ${circle.inviteCode}',
                          style: TextStyle(
                              color: c.onSurfaceMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.onSurfaceMuted),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
