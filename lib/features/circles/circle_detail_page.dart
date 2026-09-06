import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/circle.dart';
import '../../data/models/live_location.dart';
import '../../shared/components.dart';
import '../map/map_tiles.dart';

class CircleDetailPage extends ConsumerWidget {
  const CircleDetailPage({super.key, required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final membersAsync = ref.watch(circleMembersProvider(circle.id));

    return GlassScaffold(
      appBar: GlassAppBar(
        title: circle.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Copy invite code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: circle.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invite code ${circle.inviteCode} copied')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text('Could not load members',
                style: TextStyle(color: c.onSurfaceMuted)),
          ),
          data: (members) {
            final located =
                members.where((m) => m.latLng != null).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Container(
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: c.shadowDark, blurRadius: 14)],
                  ),
                  child: located.isEmpty
                      ? Container(
                          color: c.surfaceLow,
                          alignment: Alignment.center,
                          child: Text('No members are sharing location yet',
                              style: TextStyle(color: c.onSurfaceMuted)),
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCameraFit: CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(
                                located.map((m) => m.latLng!).toList(),
                              ),
                              padding: const EdgeInsets.all(48),
                            ),
                          ),
                          children: [
                            journeyTileLayer(),
                            MarkerLayer(
                              markers: [
                                for (final m in located)
                                  Marker(
                                    point: m.latLng!,
                                    width: 44,
                                    height: 44,
                                    child: NeoAvatar(
                                      name: m.displayName,
                                      radius: 18,
                                      online: m.isOnline,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                NeoSectionHeader('${members.length} members'),
                for (final m in members) _MemberRow(member: m),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final LiveLocation member;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoCard(
        child: Row(
          children: [
            NeoAvatar(
              name: member.displayName,
              radius: 22,
              online: member.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    member.isOnline
                        ? (member.activity ?? 'Online')
                        : 'Last seen ${Fmt.ago(member.updatedAt)}',
                    style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (member.batteryLevel != null)
              Text('${member.batteryLevel}%',
                  style: TextStyle(
                      color: c.onSurfaceMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
