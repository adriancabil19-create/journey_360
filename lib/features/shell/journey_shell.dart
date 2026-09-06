import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass.dart';
import '../../core/providers.dart';
import '../../services/crash_detector.dart';
import '../activity/activity_page.dart';
import '../analytics/analytics_page.dart';
import '../journey/tracking_controller.dart';
import '../map/map_page.dart';

/// The three-mode Journey360 shell: family safety, workouts, and performance.
class JourneyShell extends ConsumerStatefulWidget {
  const JourneyShell({super.key});

  @override
  ConsumerState<JourneyShell> createState() => _JourneyShellState();
}

class _JourneyShellState extends ConsumerState<JourneyShell> {
  int _index = 0;
  late final CrashDetector _crashDetector;

  /// Tabs are built the first time they are opened and then kept alive. The Map
  /// tab runs a live location stream, so it should not mount until visited.
  final _visited = <int>{0};

  static const _pages = [
    MapPage(),
    ActivityPage(),
    AnalyticsPage(),
  ];

  static const _items = [
    _NavItem('Circle', Icons.shield_rounded, Icons.shield_outlined),
    _NavItem('Workout', Icons.bolt_rounded, Icons.bolt_outlined),
    _NavItem('Insights', Icons.insights_rounded, Icons.insights_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _crashDetector = CrashDetector(endpoint: AppConfig.sosEndpoint);
    _crashDetector.start(onCrash: _showCrashAlert);
  }

  Future<void> _showCrashAlert(CrashEvent event) async {
    if (!mounted) return;
    final state = ref.read(trackingControllerProvider);
    final shouldDispatch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_rounded, color: context.colors.danger, size: 40),
        title: const Text('Are you okay?'),
        content: Text('A possible crash was detected at ${event.gForce.toStringAsFixed(1)}G. Dispatch will be notified unless you cancel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('I am okay')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send help')),
        ],
      ),
    );
    if (shouldDispatch != true || state.here == null || !mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || AppConfig.sosEndpoint.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add SOS_ENDPOINT to enable emergency dispatch.')));
      return;
    }
    try {
      await _crashDetector.dispatch(
        userId: user.id,
        userName: (user.userMetadata?['full_name'] as String?) ?? 'Journey360 member',
        latitude: state.here!.latitude,
        longitude: state.here!.longitude,
        alertType: 'CRASH_DETECTED',
        speedMph: (state.lastPosition?.speed ?? 0) * 2.23694,
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatch could not connect. SOS is still available from Circle.')));
    }
  }

  @override
  void dispose() {
    _crashDetector.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _visited.contains(i)
                  ? RepaintBoundary(child: _pages[i])
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _FloatingNav(
          index: _index,
          items: _items,
          onSelect: _go,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.active, this.inactive);
  final String label;
  final IconData active;
  final IconData inactive;
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.items,
    required this.onSelect,
  });

  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassSurface(
          radius: 30,
          blur: 24,
          strong: true,
          pressable: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    c.accent.withValues(alpha: 0.9),
                    Color.lerp(c.accent, Colors.black, 0.18)!
                        .withValues(alpha: 0.9),
                  ],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.active : item.inactive,
              size: 22,
              color: selected ? Colors.white : c.onSurfaceMuted,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
