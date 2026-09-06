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
      await ref.read(trackingControllerProvider.notifier).enablePassiveTracking();
      return;
    }
    if (_askedThisSession || !mounted) return;
    _askedThisSession = true;
    final proceed = await showLocationRationale(context);
    if (proceed != true || !mounted) return;
    final result =
        await ref.read(trackingControllerProvider.notifier).enablePassiveTracking();
    if (result == LocationAccess.deniedForever && mounted) {
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
                  if (selectedCircle != null) ...[
                    const SizedBox(height: 10),
                    _CirclePicker(
                      circles: circles,
                      selected: selectedCircle,
                      onSelected: (id) => ref
                          .read(selectedCircleIdProvider.notifier)
                          .state = id,
                    ),
                  ],
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

          // Bottom status card (sits above the floating nav bar).
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

class _CirclePicker extends StatelessWidget {
  const _CirclePicker({
    required this.circles,
    required this.selected,
    required this.onSelected,
  });

  final List<Circle> circles;
  final Circle selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: c.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selected.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w800),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Switch circle',
            initialValue: selected.id,
            onSelected: onSelected,
            icon: Icon(Icons.expand_more_rounded, color: c.onSurfaceMuted),
            itemBuilder: (context) => [
              for (final circle in circles)
                PopupMenuItem<String>(
                  value: circle.id,
                  child: Row(
                    children: [
                      Icon(
                        circle.id == selected.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: circle.id == selected.id
                            ? c.accent
                            : c.onSurfaceMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(circle.name),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
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
                  : 'You are here. Start an activity to record a route.',
              style: TextStyle(color: c.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}
