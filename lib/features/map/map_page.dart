import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../../core/providers.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/page_transition.dart';
import '../../data/models/circle.dart';
import '../../data/models/live_location.dart';
import '../../shared/components.dart';
import '../journey/tracking_controller.dart';
import '../settings/settings_controller.dart';
import '../circles/circles_page.dart';
import '../settings/feature_pages.dart';
import 'places_page.dart';
import 'location_permission_sheet.dart';
import 'map_tiles.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();
  bool _askedThisSession = false;
  bool _followMe = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLocation());
  }

  Future<void> _bootstrapLocation() async {
    final service = ref.read(locationServiceProvider);
    final access = await service.currentAccess();
    if (access == LocationAccess.granted) {
      await ref.read(sharedPreferencesProvider).setBool(
            'journey360.location-granted-before',
            true,
          );
      await ref.read(trackingControllerProvider.notifier).enablePassiveTracking();
      return;
    }
    final grantedBefore = ref
            .read(sharedPreferencesProvider)
            .getBool('journey360.location-granted-before') ??
        false;
    if (_askedThisSession || grantedBefore || !mounted) {
      if (grantedBefore && mounted) {
        final retry = await ref
            .read(trackingControllerProvider.notifier)
            .enablePassiveTracking();
        if (retry == LocationAccess.deniedForever && mounted) {
          _showLocationSettingsMessage(service);
        }
      }
      return;
    }
    _askedThisSession = true;
    final proceed = await showLocationRationale(context);
    if (proceed != true || !mounted) return;
    final result =
        await ref.read(trackingControllerProvider.notifier).enablePassiveTracking();
    if (result == LocationAccess.granted) {
      await ref.read(sharedPreferencesProvider).setBool(
            'journey360.location-granted-before',
            true,
          );
    }
    if (result == LocationAccess.deniedForever && mounted) {
      _showLocationSettingsMessage(service);
    }
  }

  void _showLocationSettingsMessage(LocationService service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location is blocked in system settings.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => service.openAppSettings(),
        ),
      ),
    );
  }

  void _recenter() {
    final here = ref.read(trackingControllerProvider).here;
    if (here != null) {
      setState(() => _followMe = true);
      _map.move(here, 16);
    } else {
      _bootstrapLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(trackingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final backend = ref.watch(backendEnabledProvider);
    final circles = ref.watch(circlesProvider).valueOrNull ?? const [];
    final selectedId = ref.watch(selectedCircleIdProvider);
    final selectedCircle = circles.isEmpty
        ? null
        : circles.firstWhere(
            (circle) => circle.id == selectedId,
            orElse: () => circles.first,
          );
    final activeAlert = backend && circles.isNotEmpty
      ? ref.watch(activeSosProvider(selectedCircle!.id)).valueOrNull
      : null;

    ref.listen(trackingControllerProvider, (prev, next) {
      final here = next.here;
      if (here != null && _followMe && prev?.here != here) {
        _map.move(here, _map.camera.zoom < 3 ? 16 : _map.camera.zoom);
      }
    });

    // Live circle members from the selected circle, when a backend is present.
    final members = <LiveLocation>[];
    if (backend) {
      if (selectedCircle != null) {
        members.addAll(
          ref.watch(circleMembersProvider(selectedCircle.id)).valueOrNull ??
              const [],
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: state.here ?? const LatLng(20, 0),
                initialZoom: state.here == null ? 2.4 : 16,
                onPointerDown: (_, _) {
                  if (_followMe) setState(() => _followMe = false);
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                journeyTileLayer(),
                if (state.route.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: state.route,
                        strokeWidth: 6,
                        color: c.accent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final m in members)
                      if (m.latLng != null)
                        Marker(
                          point: m.latLng!,
                          width: 54,
                          height: 66,
                          child: _MemberPin(member: m),
                        ),
                    if (state.here != null)
                      Marker(
                        point: state.here!,
                        width: 30,
                        height: 30,
                        child: _SelfPin(color: c.accent, surface: c.surface),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(journeyMapAttribution),
                  ],
                ),
              ],
              ),
            ),
          ),

          // Top: search + sharing pill.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  GlassPanel(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: c.onSurfaceMuted, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Search places',
                          style: TextStyle(color: c.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SharingPill(
                        on: settings.sharingMode.isOn,
                        onTap: () => ref
                            .read(settingsControllerProvider.notifier)
                            .toggleSharing(),
                      ),
                      const Spacer(),
                      NeoIconButton(
                        icon: Icons.groups_rounded,
                        tooltip: 'Manage circles',
                        onTap: () => context.pushJourney(const CirclesPage()),
                      ),
                      const SizedBox(width: 8),
                      NeoIconButton(
                        icon: Icons.place_outlined,
                        tooltip: 'Saved places',
                        onTap: () => context.pushJourney(const PlacesPage()),
                      ),
                      const SizedBox(width: 8),
                      NeoButton(
                        label: 'SOS',
                        icon: Icons.sos_rounded,
                        tone: NeoButtonTone.danger,
                        expand: false,
                        onPressed: backend && circles.isNotEmpty
                            ? _sendSos
                            : null,
                      ),
                    ],
                  ),
                  if (activeAlert != null) ...[
                    const SizedBox(height: 10),
                    GlassPanel(
                      tint: c.danger.withValues(alpha: 0.18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_rounded, color: c.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SOS active in ${selectedCircle!.name}',
                              style: TextStyle(
                                color: c.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Right controls.
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeoIconButton(
                      icon: Icons.add,
                      onTap: () => _map.move(
                        _map.camera.center,
                        _map.camera.zoom + 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NeoIconButton(
                      icon: Icons.remove,
                      onTap: () => _map.move(
                        _map.camera.center,
                        _map.camera.zoom - 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NeoIconButton(
                      icon: Icons.my_location,
                      tone: _followMe ? c.accent : c.onSurfaceMuted,
                      onTap: _recenter,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Life360-style draggable circle home sheet.
          if (selectedCircle != null)
            Positioned.fill(
              child: DraggableScrollableSheet(
                initialChildSize: 0.29,
                minChildSize: 0.24,
                maxChildSize: 0.78,
                snap: true,
                snapSizes: const [0.29, 0.52, 0.78],
                builder: (context, scrollController) => _CircleHomeSheet(
                  circle: selectedCircle,
                  circles: circles,
                  members: members,
                  travelMode: state.travelMode,
                  scrollController: scrollController,
                  onCircleSelected: (id) => ref
                      .read(selectedCircleIdProvider.notifier)
                      .state = id,
                  onManage: () => context.pushJourney(const CirclesPage()),
                  onAddPerson: () => context.pushJourney(const CirclesPage()),
                  onPlaces: () => context.pushJourney(const PlacesPage()),
                  onSettings: () => context.pushJourney(const SmartNotificationsPage()),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                  child: _StatusCard(state: state),
                ),
              ),
            ),

          if (state.error != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 168),
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: c.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendSos() async {
    final circles = ref.read(circlesProvider).valueOrNull ?? const [];
    if (circles.isEmpty) return;
    final selectedId = ref.read(selectedCircleIdProvider);
    final circle = circles.firstWhere(
      (item) => item.id == selectedId,
      orElse: () => circles.first,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send SOS?'),
        content: Text(
          'Your ${circle.name} circle will receive an emergency alert '
          'with your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final here = ref.read(trackingControllerProvider).here;
      await ref.read(supabaseSourceProvider).sendSos(
        circleId: circle.id,
            latitude: here?.latitude,
            longitude: here?.longitude,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS sent to your circle.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send SOS: $error')),
      );
    }
  }
}

class _SelfPin extends StatelessWidget {
  const _SelfPin({required this.color, required this.surface});
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: surface, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
    );
  }
}

class _MemberPin extends StatelessWidget {
  const _MemberPin({required this.member});
  final LiveLocation member;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _MemberSheet(member: member),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeoAvatar(
            name: member.displayName,
            radius: 20,
            online: member.isOnline,
            imageUrl: member.avatarUrl,
          ),
          Icon(Icons.arrow_drop_down, color: context.colors.accent, size: 22),
        ],
      ),
    );
  }
}

class _MemberSheet extends StatelessWidget {
  const _MemberSheet({required this.member});
  final LiveLocation member;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassSurface(
      radius: 26,
      blur: 24,
      strong: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeoAvatar(
                name: member.displayName,
                radius: 26,
                online: member.isOnline,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 9,
                          color: member.isOnline ? c.online : c.onSurfaceMuted),
                      const SizedBox(width: 6),
                      Text(
                        member.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: c.onSurfaceMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kv(context, 'Battery',
              member.batteryLevel == null ? '—' : '${member.batteryLevel}%'),
          _kv(context, 'Status', member.activity ?? 'Not moving'),
          _kv(context, 'Updated', Fmt.ago(member.updatedAt)),
        ],
      ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: c.onSurfaceMuted)),
          Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = state.stats;
    if (state.isRecording && s != null) {
      return NeoCard(
        color: c.accent,
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
            const SizedBox(width: 10),
            Text(
              '${Fmt.km(s.distanceMeters)} km',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              s.type.verb,
              style: const TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            Text(
              Fmt.duration(s.elapsedSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return NeoCard(
      child: Row(
        children: [
          Icon(Icons.near_me_outlined, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.here == null
                  ? 'Finding your location…'
                  : state.lastPosition == null && state.lastFixAt != null
                      ? 'Last known location ${Fmt.ago(state.lastFixAt)}. Waiting for a fresh fix.'
                      : 'You are here. Start an activity to record a route.',
              style: TextStyle(color: c.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleHomeSheet extends StatelessWidget {
  const _CircleHomeSheet({
    required this.circle,
    required this.circles,
    required this.members,
    required this.travelMode,
    required this.scrollController,
    required this.onCircleSelected,
    required this.onManage,
    required this.onAddPerson,
    required this.onPlaces,
    required this.onSettings,
  });

  final Circle circle;
  final List<Circle> circles;
  final List<LiveLocation> members;
  final TravelMode travelMode;
  final ScrollController scrollController;
  final ValueChanged<String> onCircleSelected;
  final VoidCallback onManage;
  final VoidCallback onAddPerson;
  final VoidCallback onPlaces;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceHigh.withValues(alpha: .97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, -8)),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(color: c.onSurfaceMuted.withValues(alpha: .28), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),
          NeoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  travelMode == TravelMode.driving
                      ? Icons.directions_car_filled_rounded
                      : Icons.speed_rounded,
                  color: travelMode == TravelMode.driving ? c.drive : c.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    travelMode == TravelMode.driving
                        ? 'Driving detected from GPS speed'
                        : 'Travel mode: ${travelMode.label}',
                    style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w800),
                  ),
                ),
                if (travelMode == TravelMode.driving)
                  Text('AUTO', style: TextStyle(color: c.drive, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(circle.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        if (circles.length > 1)
                          PopupMenuButton<String>(
                            tooltip: 'Switch group',
                            onSelected: onCircleSelected,
                            icon: Icon(Icons.expand_more_rounded, color: c.accent),
                            itemBuilder: (context) => [
                              for (final item in circles)
                                PopupMenuItem(value: item.id, child: Text(item.name)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${members.length} people in this circle', style: TextStyle(color: c.onSurfaceMuted)),
                  ],
                ),
              ),
              IconButton(onPressed: onSettings, icon: Icon(Icons.settings_outlined, color: c.accent), tooltip: 'Settings'),
              IconButton(onPressed: onManage, icon: Icon(Icons.more_horiz_rounded, color: c.onSurfaceMuted), tooltip: 'Circle management'),
            ],
          ),
          const SizedBox(height: 14),
          _SheetQuickActions(
            onAddPerson: onAddPerson,
            onPlaces: onPlaces,
            onManage: onManage,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('People', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(onPressed: onAddPerson, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Add person')),
            ],
          ),
          if (members.isEmpty)
            NeoCard(
              child: Row(children: [Icon(Icons.group_outlined, color: c.accent), const SizedBox(width: 12), Expanded(child: Text('Invite people to start sharing live location.', style: TextStyle(color: c.onSurfaceMuted))),]),
            )
          else
            for (final member in members) _CircleMemberCard(member: member),
          const SizedBox(height: 18),
          Text('Circle tools', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _SheetFeatureRow(icon: Icons.notifications_active_outlined, title: 'Smart notifications', subtitle: 'Circle alerts and activity updates', onTap: onSettings),
          _SheetFeatureRow(icon: Icons.place_outlined, title: 'Saved places', subtitle: 'Home, work, school and geofences', onTap: onPlaces),
          _SheetFeatureRow(icon: Icons.speed_rounded, title: 'Auto travel detection', subtitle: 'Driving is detected from sustained GPS speed', onTap: onManage),
          _SheetFeatureRow(icon: Icons.shield_outlined, title: 'Circle management', subtitle: 'Invite, remove, or switch circles', onTap: onManage),
        ],
      ),
    );
  }
}

class _SheetQuickActions extends StatelessWidget {
  const _SheetQuickActions({required this.onAddPerson, required this.onPlaces, required this.onManage});
  final VoidCallback onAddPerson;
  final VoidCallback onPlaces;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _QuickAction(icon: Icons.group_add_rounded, label: 'Invite', onTap: onAddPerson, color: c.accent),
        _QuickAction(icon: Icons.place_rounded, label: 'Places', onTap: onPlaces, color: c.run),
        _QuickAction(icon: Icons.speed_rounded, label: 'Travel', onTap: onManage, color: c.drive),
        _QuickAction(icon: Icons.swap_horiz_rounded, label: 'Switch', onTap: onManage, color: c.cycle),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, required this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(icon, color: color)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: context.colors.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _CircleMemberCard extends StatelessWidget {
  const _CircleMemberCard({required this.member});
  final LiveLocation member;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeoCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          NeoAvatar(name: member.displayName, radius: 24, online: member.isOnline, imageUrl: member.avatarUrl),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(member.displayName, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text(member.isOnline ? (member.activity ?? 'At current location') : 'Last seen ${Fmt.ago(member.updatedAt)}', style: TextStyle(color: c.onSurfaceMuted, fontSize: 12.5))])),
          if (member.batteryLevel != null) Row(children: [Icon(Icons.battery_5_bar_rounded, size: 17, color: c.online), const SizedBox(width: 3), Text('${member.batteryLevel}%', style: TextStyle(color: c.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
        ]),
      ),
    );
  }
}

class _SheetFeatureRow extends StatelessWidget {
  const _SheetFeatureRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeoCard(onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: c.accent)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: c.onSurfaceMuted, fontSize: 12))])), Icon(Icons.chevron_right_rounded, color: c.onSurfaceMuted)])),
    );
  }
}
