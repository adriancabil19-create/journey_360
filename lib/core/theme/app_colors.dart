import 'package:flutter/material.dart';

/// Journey360 colour tokens.
///
/// A glassmorphic system: translucent frosted surfaces float above a soft
/// aurora-gradient background. One strong accent (teal). Full light + dark.
/// Activity families are differentiated with subtle tints only.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceLow,
    required this.accent,
    required this.accentSoft,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.shadowDark,
    required this.shadowLight,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.bgTop,
    required this.bgBottom,
    required this.auroraA,
    required this.auroraB,
    required this.auroraC,
    required this.run,
    required this.walk,
    required this.drive,
    required this.cycle,
    required this.danger,
    required this.online,
  });

  final Color surface;
  final Color surfaceHigh;
  final Color surfaceLow;
  final Color accent;
  final Color accentSoft;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color shadowDark;
  final Color shadowLight;

  /// Default translucent frosted fill for glass panels.
  final Color glassFill;

  /// A more opaque frosted fill for panels that carry dense text.
  final Color glassFillStrong;

  /// Hairline border on the shadowed edge of a glass panel.
  final Color glassBorder;

  /// Bright hairline on the lit (top-left) edge of a glass panel.
  final Color glassHighlight;

  /// Aurora background gradient stops.
  final Color bgTop;
  final Color bgBottom;
  final Color auroraA;
  final Color auroraB;
  final Color auroraC;

  final Color run;
  final Color walk;
  final Color drive;
  final Color cycle;
  final Color danger;
  final Color online;

  static const light = AppColors(
    surface: Color(0xFFEAF0F2),
    surfaceHigh: Color(0xFFF5F8FA),
    surfaceLow: Color(0xFFDCE4E8),
    accent: Color(0xFF12857A),
    accentSoft: Color(0xFFD6EBE7),
    onSurface: Color(0xFF122228),
    // Darkened from #5A6C74 to clear WCAG AA (4.5:1) for small text on glass.
    onSurfaceMuted: Color(0xFF4C5E66),
    shadowDark: Color(0x2A5B7A82),
    shadowLight: Color(0xFFFFFFFF),
    glassFill: Color(0xC2FFFFFF),
    glassFillStrong: Color(0xF2FAFDFD),
    glassBorder: Color(0x5CFFFFFF),
    glassHighlight: Color(0xB0FFFFFF),
    bgTop: Color(0xFFEFF4F5),
    bgBottom: Color(0xFFE2ECEC),
    auroraA: Color(0xFF34C5B0),
    auroraB: Color(0xFF7FB6E6),
    auroraC: Color(0xFFF3D9A8),
    run: Color(0xFF12857A),
    walk: Color(0xFF3E7CB1),
    drive: Color(0xFFB4692A),
    cycle: Color(0xFF6D5AAE),
    danger: Color(0xFFD9553B),
    online: Color(0xFF2FA36B),
  );

  static const dark = AppColors(
    surface: Color(0xFF161C20),
    surfaceHigh: Color(0xFF1E262B),
    surfaceLow: Color(0xFF11161A),
    accent: Color(0xFF3FC3B1),
    accentSoft: Color(0xFF1C3733),
    onSurface: Color(0xFFEAF2F3),
    // Lightened from #8D9BA1 to clear WCAG AA (4.5:1) for small text on glass.
    onSurfaceMuted: Color(0xFF9AA8AE),
    shadowDark: Color(0x66000000),
    shadowLight: Color(0x0FFFFFFF),
    glassFill: Color(0xC22A343B),
    glassFillStrong: Color(0xF21A2228),
    glassBorder: Color(0x2EFFFFFF),
    glassHighlight: Color(0x40FFFFFF),
    bgTop: Color(0xFF10171B),
    bgBottom: Color(0xFF0B1013),
    auroraA: Color(0xFF0E6E64),
    auroraB: Color(0xFF244C6B),
    auroraC: Color(0xFF5A4A73),
    run: Color(0xFF3FC3B1),
    walk: Color(0xFF6BA7D6),
    drive: Color(0xFFD68A4E),
    cycle: Color(0xFF9E8BD8),
    danger: Color(0xFFE9765C),
    online: Color(0xFF4FC489),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceLow,
    Color? accent,
    Color? accentSoft,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? shadowDark,
    Color? shadowLight,
    Color? glassFill,
    Color? glassFillStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? bgTop,
    Color? bgBottom,
    Color? auroraA,
    Color? auroraB,
    Color? auroraC,
    Color? run,
    Color? walk,
    Color? drive,
    Color? cycle,
    Color? danger,
    Color? online,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      shadowDark: shadowDark ?? this.shadowDark,
      shadowLight: shadowLight ?? this.shadowLight,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      bgTop: bgTop ?? this.bgTop,
      bgBottom: bgBottom ?? this.bgBottom,
      auroraA: auroraA ?? this.auroraA,
      auroraB: auroraB ?? this.auroraB,
      auroraC: auroraC ?? this.auroraC,
      run: run ?? this.run,
      walk: walk ?? this.walk,
      drive: drive ?? this.drive,
      cycle: cycle ?? this.cycle,
      danger: danger ?? this.danger,
      online: online ?? this.online,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      surfaceLow: l(surfaceLow, other.surfaceLow),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceMuted: l(onSurfaceMuted, other.onSurfaceMuted),
      shadowDark: l(shadowDark, other.shadowDark),
      shadowLight: l(shadowLight, other.shadowLight),
      glassFill: l(glassFill, other.glassFill),
      glassFillStrong: l(glassFillStrong, other.glassFillStrong),
      glassBorder: l(glassBorder, other.glassBorder),
      glassHighlight: l(glassHighlight, other.glassHighlight),
      bgTop: l(bgTop, other.bgTop),
      bgBottom: l(bgBottom, other.bgBottom),
      auroraA: l(auroraA, other.auroraA),
      auroraB: l(auroraB, other.auroraB),
      auroraC: l(auroraC, other.auroraC),
      run: l(run, other.run),
      walk: l(walk, other.walk),
      drive: l(drive, other.drive),
      cycle: l(cycle, other.cycle),
      danger: l(danger, other.danger),
      online: l(online, other.online),
    );
  }
}

/// Convenience accessor: `context.colors.accent`.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
