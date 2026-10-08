import 'package:flutter/material.dart';

import '../../domain/appearance/appearance_catalog.dart';
import 'status_farben.dart';

/// Zentrale Farbdefinitionen der DPSG App.
/// Hinweis: Domain-Layer sollte diese Datei nicht importieren. Falls `Stufe`
/// weiter rein domain-orientiert bleiben soll, kann man alternativ ein Mapping
/// im UI Layer bereitstellen. Aktuell folgt diese Datei der Nutzeranforderung
/// direkt und liefert `Color` Konstanten.
abstract class DPSGColors {
  // Primary colors (Light/Dark differ per OD design)
  static const primaryLight = Color(0xFF003056);
  static const primaryDark = Color(0xFF5A9AD8);

  static const secondary = Color(0xFF810a1a);
  static const biberFarbe = Color(0xFFFFFFFF);
  static const woelfingFarbe = Color(0xFFFF6400);
  static const jungpfadfinderFarbe = Color(0xFF2f53a7);
  static const pfadfinderFarbe = Color(0xFF00823c);
  static const roverFarbe = Color(0xFFcc1f2f);
  static const leiterFarbe = Color.fromARGB(255, 255, 247, 24);
  static const keineStufeFarbe = Colors.grey;

  // OD Dark Mode Colors (--D tokens)
  static const darkBg = Color(0xFF0E0E12); // --bg
  static const darkSurface = Color(0xFF1A1A22); // --surface
  static const darkFg = Color(0xFFF0F0F5); // --fg
  static const darkMuted = Color(0xFF8A8A9A); // --muted
  static const darkBorder = Color(0xFF2E2E3A); // --border
  static const darkDivider = Color(0xFF1C1C26); // --divider
  static const darkPrimaryLite = Color(0xFF1A253A); // --primary-lite
  static const darkError = Color(0xFFFF5050); // --error
  static const darkSuccess = Color(0xFF22C65A); // --success

  // OD Light Mode Colors (--L tokens)
  static const lightBg = Color(0xFFF5F5F7); // --bg
  static const lightSurface = Color(0xFFFFFFFF); // --surface
  static const lightFg = Color(0xFF1C1C1E); // --fg
  static const lightMuted = Color(0xFF8E8E93); // --muted
  static const lightBorder = Color(0xFFE5E5EA); // --border
  static const lightDivider = Color(0xFFF2F2F7); // --divider
  static const lightPrimaryLite = Color(0xFFE8EDF5); // --primary-lite
  static const lightError = Color(0xFFCC1F2F); // --error
  static const lightSuccess = Color(0xFF00823C); // --success
}

/// Farbwerte einer Palette fuer eine Helligkeit. Die Tokens entsprechen den
/// OD-Tokens aus [DPSGColors].
class AppPaletteColors {
  const AppPaletteColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.bg,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.border,
    required this.primaryLite,
    required this.error,
    required this.success,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color bg;
  final Color surface;
  final Color fg;
  final Color muted;
  final Color border;
  final Color primaryLite;
  final Color error;
  final Color success;
}

class AppPalette {
  const AppPalette({required this.light, required this.dark});

  final AppPaletteColors light;
  final AppPaletteColors dark;

  AppPaletteColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Farbpaletten fuer das Erscheinungsbild. Quelle:
/// design/supporter/palettes.json.
const Map<AppPaletteId, AppPalette> appPalettes = {
  AppPaletteId.standard: AppPalette(
    light: AppPaletteColors(
      primary: DPSGColors.primaryLight,
      onPrimary: Colors.white,
      secondary: DPSGColors.secondary,
      bg: DPSGColors.lightBg,
      surface: DPSGColors.lightSurface,
      fg: DPSGColors.lightFg,
      muted: DPSGColors.lightMuted,
      border: DPSGColors.lightBorder,
      primaryLite: DPSGColors.lightPrimaryLite,
      error: DPSGColors.lightError,
      success: DPSGColors.lightSuccess,
    ),
    dark: AppPaletteColors(
      primary: DPSGColors.primaryDark,
      onPrimary: DPSGColors.darkBg,
      secondary: DPSGColors.secondary,
      bg: DPSGColors.darkBg,
      surface: DPSGColors.darkSurface,
      fg: DPSGColors.darkFg,
      muted: DPSGColors.darkMuted,
      border: DPSGColors.darkBorder,
      primaryLite: DPSGColors.darkPrimaryLite,
      error: DPSGColors.darkError,
      success: DPSGColors.darkSuccess,
    ),
  ),
  AppPaletteId.waldsee: AppPalette(
    light: AppPaletteColors(
      primary: Color(0xFF2F5D46),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF8A5A2B),
      bg: Color(0xFFF1F4EF),
      surface: Color(0xFFFFFFFF),
      fg: Color(0xFF1B2420),
      muted: Color(0xFF6F7C74),
      border: Color(0xFFDCE3DB),
      primaryLite: Color(0xFFE2EBE4),
      error: Color(0xFFB3261E),
      success: Color(0xFF2E7D4F),
    ),
    dark: AppPaletteColors(
      primary: Color(0xFF86C3A0),
      onPrimary: Color(0xFF0D1510),
      secondary: Color(0xFFC8955B),
      bg: Color(0xFF0E1511),
      surface: Color(0xFF17211B),
      fg: Color(0xFFE8EFEA),
      muted: Color(0xFF8A9A90),
      border: Color(0xFF26332B),
      primaryLite: Color(0xFF1B2B22),
      error: Color(0xFFF2786E),
      success: Color(0xFF5CCB86),
    ),
  ),
  AppPaletteId.lagerfeuer: AppPalette(
    light: AppPaletteColors(
      primary: Color(0xFF9C421B),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF3E5A6B),
      bg: Color(0xFFF7F1EB),
      surface: Color(0xFFFFFDFB),
      fg: Color(0xFF2A1E18),
      muted: Color(0xFF85766C),
      border: Color(0xFFEBDFD4),
      primaryLite: Color(0xFFF5E3D7),
      error: Color(0xFFB3261E),
      success: Color(0xFF3C7A4A),
    ),
    dark: AppPaletteColors(
      primary: Color(0xFFF0985E),
      onPrimary: Color(0xFF1A0F0A),
      secondary: Color(0xFF8FB3C4),
      bg: Color(0xFF15100D),
      surface: Color(0xFF211915),
      fg: Color(0xFFF3E9E2),
      muted: Color(0xFFA08F84),
      border: Color(0xFF372A23),
      primaryLite: Color(0xFF3A2419),
      error: Color(0xFFFF7A6B),
      success: Color(0xFF6CC88A),
    ),
  ),
  AppPaletteId.nachthimmel: AppPalette(
    light: AppPaletteColors(
      primary: Color(0xFF2E3F7A),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF9A6F1F),
      bg: Color(0xFFF2F3F8),
      surface: Color(0xFFFFFFFF),
      fg: Color(0xFF181C2B),
      muted: Color(0xFF72778D),
      border: Color(0xFFDFE1EB),
      primaryLite: Color(0xFFE4E7F4),
      error: Color(0xFFB3261E),
      success: Color(0xFF2E7D4F),
    ),
    dark: AppPaletteColors(
      primary: Color(0xFF9FB2F2),
      onPrimary: Color(0xFF0B0F1D),
      secondary: Color(0xFFE3B45A),
      bg: Color(0xFF0B0F1D),
      surface: Color(0xFF141A2C),
      fg: Color(0xFFE9ECF7),
      muted: Color(0xFF8A90A8),
      border: Color(0xFF262D45),
      primaryLite: Color(0xFF1B2446),
      error: Color(0xFFFF7F7F),
      success: Color(0xFF5CCB86),
    ),
  ),
  AppPaletteId.hochkontrast: AppPalette(
    light: AppPaletteColors(
      primary: Color(0xFF002A4D),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF7A0010),
      bg: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      fg: Color(0xFF000000),
      muted: Color(0xFF3D3D3D),
      border: Color(0xFF1A1A1A),
      primaryLite: Color(0xFFD6E4F2),
      error: Color(0xFFA30016),
      success: Color(0xFF005C2A),
    ),
    dark: AppPaletteColors(
      primary: Color(0xFF8CC8FF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFFF8A96),
      bg: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      fg: Color(0xFFFFFFFF),
      muted: Color(0xFFCFCFCF),
      border: Color(0xFFFFFFFF),
      primaryLite: Color(0xFF0B2A45),
      error: Color(0xFFFF6B6B),
      success: Color(0xFF4CE08A),
    ),
  ),
};

ThemeData buildTheme(AppPaletteId paletteId, Brightness brightness) {
  final c = appPalettes[paletteId]!.of(brightness);
  final isDark = brightness == Brightness.dark;
  // ColorScheme.light/.dark behalten die bisherigen Defaults der Standardpalette bei.
  final scheme = isDark
      ? ColorScheme.dark(
          brightness: brightness,
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primaryLite,
          onPrimaryContainer: c.fg,
          secondary: c.secondary,
          onSecondary: Colors.white,
          tertiary: c.muted,
          onTertiary: c.fg,
          error: c.error,
          onError: c.bg,
          errorContainer: c.error.withValues(alpha: 0.12),
          onErrorContainer: c.error,
          surface: c.surface,
          onSurface: c.fg,
          surfaceContainerHighest: c.border,
          outline: c.border,
          outlineVariant: c.muted,
          scrim: c.bg,
          shadow: const Color(0xFF000000),
        )
      : ColorScheme.light(
          brightness: brightness,
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.primaryLite,
          onPrimaryContainer: c.primary,
          secondary: c.secondary,
          onSecondary: Colors.white,
          tertiary: c.muted,
          onTertiary: Colors.white,
          error: c.error,
          onError: Colors.white,
          errorContainer: c.error.withValues(alpha: 0.12),
          onErrorContainer: c.error,
          surface: c.surface,
          onSurface: c.fg,
          surfaceContainerHighest: c.bg,
          outline: c.border,
          outlineVariant: c.muted,
          scrim: c.bg,
          shadow: const Color(0xFF000000).withValues(alpha: 0.12),
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[
      StatusFarben(
        gut: c.success,
        warnung: isDark ? StatusFarben.warnungDunkel : StatusFarben.warnungHell,
        kritisch: c.error,
      ),
    ],
    scaffoldBackgroundColor: c.bg,
    // Die Material-Vorgaben fuer ausgeschaltete Schalter und Segment-Raender
    // nutzen outline/surfaceContainerHighest; beide sind hier die Rahmenfarbe
    // und verschwinden auf Karten. Deshalb muted fuer alles Ausgeschaltete.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.onPrimary : c.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.primary
            : (isDark ? c.bg : c.border),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : c.muted,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.primary : c.muted,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: c.muted)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primaryLite
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? c.fg : c.primary)
              : c.fg,
        ),
      ),
    ),
    disabledColor: isDark
        ? const Color(0xFF424242)
        : const Color.fromARGB(255, 222, 222, 222),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: isDark
          ? const Color(0xFF2B2B2B)
          : const Color.fromARGB(255, 242, 242, 242),
    ),
  );
}

final darkTheme = buildTheme(AppPaletteId.standard, Brightness.dark);

final lightTheme = buildTheme(AppPaletteId.standard, Brightness.light);

class ThemeModel extends ChangeNotifier {
  ThemeMode currentMode = ThemeMode.system;

  final Future<void> Function(ThemeMode)? _persist;

  ThemeModel({Future<void> Function(ThemeMode)? persist}) : _persist = persist;

  void setTheme(ThemeMode type) {
    currentMode = type;
    notifyListeners();
    if (_persist != null) {
      _persist(type);
    }
  }
}
