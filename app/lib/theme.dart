import 'package:flutter/material.dart';

/// Colors that Material's ColorScheme has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.hairline,
    required this.muted,
    required this.panel,
    required this.success,
    required this.warning,
    required this.danger,
    required this.singBoxBg,
    required this.singBoxFg,
    required this.mihomoBg,
    required this.mihomoFg,
  });

  final Color hairline; // 0.5px borders
  final Color muted; // secondary text
  final Color panel; // in-flow tiles (metrics, current node)
  final Color success;
  final Color warning;
  final Color danger;
  final Color singBoxBg;
  final Color singBoxFg;
  final Color mihomoBg;
  final Color mihomoFg;

  static const light = AppPalette(
    hairline: Color(0xFFE3E1DA),
    muted: Color(0xFF6B6A65),
    panel: Color(0xFFF2F1EC),
    success: Color(0xFF3B6D11),
    warning: Color(0xFF854F0B),
    danger: Color(0xFFA32D2D),
    singBoxBg: Color(0xFFEEEDFE),
    singBoxFg: Color(0xFF3C3489),
    mihomoBg: Color(0xFFE1F5EE),
    mihomoFg: Color(0xFF085041),
  );

  static const dark = AppPalette(
    hairline: Color(0xFF3D3D3A),
    muted: Color(0xFFA3A29C),
    panel: Color(0xFF2C2C2A),
    success: Color(0xFF97C459),
    warning: Color(0xFFEF9F27),
    danger: Color(0xFFF09595),
    singBoxBg: Color(0xFF3C3489),
    singBoxFg: Color(0xFFCECBF6),
    mihomoBg: Color(0xFF085041),
    mihomoFg: Color(0xFF9FE1CB),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      hairline: l(hairline, other.hairline),
      muted: l(muted, other.muted),
      panel: l(panel, other.panel),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      singBoxBg: l(singBoxBg, other.singBoxBg),
      singBoxFg: l(singBoxFg, other.singBoxFg),
      mihomoBg: l(mihomoBg, other.mihomoBg),
      mihomoFg: l(mihomoFg, other.mihomoFg),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF85B7EB) : const Color(0xFF185FA5),
    onPrimary: dark ? const Color(0xFF042C53) : Colors.white,
    secondary: dark ? const Color(0xFFB5D4F4) : const Color(0xFF0C447C),
    onSecondary: dark ? const Color(0xFF042C53) : Colors.white,
    error: p.danger,
    onError: dark ? const Color(0xFF501313) : Colors.white,
    surface: dark ? const Color(0xFF262624) : Colors.white,
    onSurface: dark ? const Color(0xFFEDEDEA) : const Color(0xFF1F1E1D),
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: dark ? const Color(0xFF1C1C1B) : const Color(0xFFFAFAF8),
    surfaceContainerLow: dark ? const Color(0xFF1F1F1E) : const Color(0xFFF7F7F5),
    surfaceContainer: p.panel,
    surfaceContainerHigh: p.panel,
    surfaceContainerHighest: p.panel,
    outline: p.hairline,
    outlineVariant: p.hairline,
    secondaryContainer: dark ? const Color(0xFF0C447C) : const Color(0xFFE6F1FB),
    onSecondaryContainer: dark ? const Color(0xFFE6F1FB) : const Color(0xFF0C447C),
  );

  final hairline = BorderSide(color: p.hairline, width: 0.5);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    extensions: [p],
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 0.5, space: 0.5),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: hairline),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: p.panel,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: scheme.onSurface)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(side: BorderSide(color: p.hairline)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
