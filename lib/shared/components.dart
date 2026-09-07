import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/glass.dart';
import '../core/utils/initials.dart';

export '../core/theme/app_colors.dart' show AppColors, AppColorsX;
export '../core/theme/glass.dart'
    show Glass, GlassSurface, GlassPanel, AppBackground, GlassScaffold, GlassAppBar;

/// A frosted glass card. Optionally tappable with a soft press.
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.color,
    this.blur = 14,
    this.strong = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// When set, tints the glass with this hue (e.g. the accent for a live card).
  final Color? color;
  final double blur;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      onTap: onTap,
      padding: padding,
      radius: radius,
      blur: blur,
      tint: color,
      strong: strong,
      child: child,
    );
  }
}

/// Primary action button — vibrant accent, or frosted neutral / danger.
class NeoButton extends StatefulWidget {
  const NeoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.tone = NeoButtonTone.accent,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final NeoButtonTone tone;
  final bool busy;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

enum NeoButtonTone { accent, neutral, danger }

class _NeoButtonState extends State<NeoButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null && !widget.busy;
    final accent = widget.tone == NeoButtonTone.accent;
    final danger = widget.tone == NeoButtonTone.danger;
    final fg = accent || danger ? Colors.white : c.onSurface;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        if (!widget.busy)
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
      ],
    );

    final BoxDecoration decoration;
    if (accent) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent, Color.lerp(c.accent, Colors.black, 0.16)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _down
            ? null
            : [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      );
    } else if (danger) {
      decoration = BoxDecoration(
        color: c.danger,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _down
            ? null
            : [
                BoxShadow(
                  color: c.danger.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      );
    } else {
      decoration = Glass.fill(c, radius: 18);
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: InkWell(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: decoration,
            child: content,
          ),
        ),
        ),
      ),
    );
  }
}

/// Circular icon button on a frosted disc.
class NeoIconButton extends StatelessWidget {
  const NeoIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 48,
    this.tone,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        child: GlassSurface(
        onTap: onTap,
        radius: size / 2,
        blur: 18,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: tone ?? c.accent, size: size * 0.46),
        ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Text field sitting in a frosted well.
class NeoTextField extends StatelessWidget {
  const NeoTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.errorText,
    this.enabled = true,
    this.autofillHints,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// Validation message shown under the field and exposed to screen readers.
  final String? errorText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: hasError
              ? (Glass.fill(c, radius: 16).copyWith(
                  border: Border.all(color: c.danger, width: 1.5)))
              : Glass.fill(c, radius: 16),
          child: Semantics(
            textField: true,
            label: label,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofillHints: enabled ? autofillHints : null,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon:
                    icon == null ? null : Icon(icon, color: c.onSurfaceMuted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: c.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// A large single metric: value on top, caption under.
class NeoMetricCard extends StatelessWidget {
  const NeoMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.accentColor,
    this.compact = false,
  });

  final String value;
  final String label;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accentColor ?? c.onSurface,
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.onSurfaceMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + value + label stat tile.
class NeoStatCard extends StatelessWidget {
  const NeoStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      blur: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? c.accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// Initials avatar with an optional online dot.
class NeoAvatar extends StatelessWidget {
  const NeoAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.color,
    this.online,
    this.imageUrl,
  });

  final String name;
  final double radius;
  final Color? color;
  final bool? online;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = color ?? c.accent;
    final statusLabel = online == null
        ? ''
        : online!
            ? ', online'
            : ', offline';
    return Semantics(
      image: imageUrl != null,
      label: 'Avatar for $name$statusLabel',
      child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, Color.lerp(bg, Colors.black, 0.22)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            image: imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                    // A broken avatar URL must not throw or spam the log; the
                    // gradient circle stays as the fallback.
                    onError: (_, _) {},
                  )
                : null,
            border: Border.all(color: c.glassHighlight, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: c.shadowDark,
                  blurRadius: 10,
                  offset: const Offset(2, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: imageUrl != null
              ? null
              : Text(
                  initialsOf(name),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: radius * 0.7,
                  ),
                ),
        ),
        if (online != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: online! ? c.online : c.onSurfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
              ),
            ),
          ),
      ],
      ),
    );
  }
}

/// Glass switch row.
class NeoToggle extends StatelessWidget {
  const NeoToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.icon,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (title == null) {
      return Switch(
          value: value, onChanged: onChanged, activeTrackColor: c.accent);
    }
    return NeoCard(
      onTap: () => onChanged(!value),
      blur: 10,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: c.accent),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: c.onSurfaceMuted),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: c.accent,
          ),
        ],
      ),
    );
  }
}

/// Section label used on scrolling pages.
class NeoSectionHeader extends StatelessWidget {
  const NeoSectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: c.onSurfaceMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Friendly empty-state block.
class NeoEmptyState extends StatelessWidget {
  const NeoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NeoCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSoft.withValues(alpha: 0.6),
              border: Border.all(color: c.glassHighlight),
            ),
            child: Icon(icon, color: c.accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: c.onSurface,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceMuted, height: 1.4),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

/// The always-visible location-sharing indicator (MD section 13).
class SharingPill extends StatelessWidget {
  const SharingPill({super.key, required this.on, this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: on,
      label: on ? 'Location sharing on' : 'Location sharing off',
      child: GlassSurface(
        onTap: onTap,
        radius: 24,
        blur: 18,
        tint: on ? c.online : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.location_on : Icons.location_off,
              size: 16,
              color: on ? c.online : c.onSurfaceMuted,
            ),
            const SizedBox(width: 7),
            Text(
              on ? 'Sharing ON' : 'Sharing OFF',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: c.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A consistent page scaffold for the secondary (pushed) screens.
class NeoScaffold extends StatelessWidget {
  const NeoScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 40),
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(title: title, actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
