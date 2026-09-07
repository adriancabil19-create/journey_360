import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The aurora-gradient backdrop that every screen sits on. Glass panels are
/// translucent, so this colour field is what shows through them.
///
/// Cheap by design: a linear gradient plus two static radial blobs, isolated in
/// a [RepaintBoundary] so scrolling content never repaints it.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.showAurora = true});

  final Widget child;
  final bool showAurora;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bgTop, c.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          if (showAurora)
            RepaintBoundary(
              child: Stack(
                children: [
                  _Blob(
                      color: c.auroraA,
                      alignment: const Alignment(-1.15, -1.05),
                      size: 440),
                  _Blob(
                      color: c.auroraB,
                      alignment: const Alignment(1.3, 0.9),
                      size: 420),
                ],
              ),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.alignment,
    required this.size,
  });

  final Color color;
  final Alignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.5),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted-glass panel: a translucent fill with a lit top-left edge, a hairline
/// border and a soft drop shadow.
///
/// Performance: by default there is **no** `BackdropFilter` — the translucent
/// fill over [AppBackground] already reads as frosted glass. Pass `frost: true`
/// only for a handful of transient surfaces (modal sheets), never in lists.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = 16,
    this.frost = false,
    this.tint,
    this.strong = false,
    this.pressable = true,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Blur sigma, only applied when [frost] is true.
  final double blur;

  /// Enable a real `BackdropFilter`. Costly — reserve for modal sheets.
  final bool frost;

  /// If set, the glass takes on this hue instead of neutral frost.
  final Color? tint;

  /// Use the more opaque fill for dense text content.
  final bool strong;
  final bool pressable;
  final bool border;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

/// Backwards-compatible alias.
typedef GlassPanel = GlassSurface;

class _GlassSurfaceState extends State<GlassSurface> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tappable = widget.onTap != null;
    final baseFill = widget.tint != null
        ? widget.tint!.withValues(alpha: 0.20)
        : (widget.strong ? c.glassFillStrong : c.glassFill);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(widget.radius),
      // A brighter top-left fading to the base fill fakes a lit glass edge
      // without a non-uniform border (which cannot carry a radius).
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
              c.glassHighlight.withValues(alpha: 0.30), baseFill),
          baseFill,
          widget.tint != null
              ? widget.tint!.withValues(alpha: 0.12)
              : baseFill,
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      border:
          widget.border ? Border.all(color: c.glassBorder, width: 1) : null,
      boxShadow: [
        BoxShadow(
          color: c.shadowDark,
          blurRadius: _down ? 8 : 18,
          offset: Offset(0, _down ? 3 : 9),
        ),
      ],
    );

    Widget panel = Container(
      padding: widget.padding,
      decoration: decoration,
      child: widget.child,
    );

    if (widget.frost) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: panel,
        ),
      );
    }

    if (!tappable) return panel;

    return Semantics(
      button: true,
      child: InkWell(
      onTapDown: widget.pressable ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.pressable ? (_) => setState(() => _down = false) : null,
      onTapCancel:
          widget.pressable ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: panel,
      ),
      ),
    );
  }
}

/// Lightweight glass decorations for chips / segmented controls / wells.
class Glass {
  const Glass._();

  static BoxDecoration fill(
    AppColors c, {
    double radius = 16,
    Color? tint,
  }) {
    return BoxDecoration(
      color: tint != null ? tint.withValues(alpha: 0.20) : c.glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.glassBorder),
      boxShadow: [
        BoxShadow(
          color: c.shadowDark,
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration inset(AppColors c, {double radius = 16}) {
    return BoxDecoration(
      color: c.shadowDark.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.glassBorder),
    );
  }
}

/// A screen scaffold: transparent [Scaffold] over the [AppBackground].
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBody = true,
    this.showAurora = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBody;
  final bool showAurora;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      showAurora: showAurora,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: body,
      ),
    );
  }
}

/// A slim translucent app bar for pushed screens (no blur — cheap on scroll).
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppBar(
      backgroundColor: c.glassFillStrong,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      title: Text(title),
      actions: actions,
    );
  }
}
