import 'package:flutter/material.dart';

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

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    brightness: Brightness.dark,
    primary: DPSGColors.primaryDark, // #5A9AD8 (OD --primary)
    onPrimary: DPSGColors.darkBg, // #0E0E12 (OD --bg)
    primaryContainer: DPSGColors.darkPrimaryLite, // #1A253A (OD --primary-lite)
    onPrimaryContainer: DPSGColors.darkFg, // #F0F0F5 (OD --fg)
    secondary: DPSGColors.secondary,
    onSecondary: Colors.white,
    tertiary: DPSGColors.darkMuted,
    onTertiary: DPSGColors.darkFg,
    error: DPSGColors.darkError, // #FF5050 (OD --error)
    onError: DPSGColors.darkBg,
    errorContainer: DPSGColors.darkError.withValues(alpha: 0.12),
    onErrorContainer: DPSGColors.darkError,
    surface: DPSGColors.darkSurface, // #1A1A22 (OD --surface)
    onSurface: DPSGColors.darkFg, // #F0F0F5 (OD --fg)
    surfaceContainerHighest: DPSGColors.darkBorder, // #2E2E3A
    outline: DPSGColors.darkBorder, // #2E2E3A (OD --border)
    outlineVariant: DPSGColors.darkMuted, // #8A8A9A (OD --muted)
    scrim: DPSGColors.darkBg, // #0E0E12 (OD --bg)
    shadow: const Color(0xFF000000),
  ),
  scaffoldBackgroundColor: DPSGColors.darkBg, // #0E0E12 (OD --bg)
  disabledColor: const Color(0xFF424242),
  inputDecorationTheme: const InputDecorationTheme(
    fillColor: Color(0xFF2B2B2B),
  ),
);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    brightness: Brightness.light,
    primary: DPSGColors.primaryLight, // #003056 (OD --primary)
    onPrimary: Colors.white,
    primaryContainer:
        DPSGColors.lightPrimaryLite, // #E8EDF5 (OD --primary-lite)
    onPrimaryContainer: DPSGColors.primaryLight,
    secondary: DPSGColors.secondary,
    onSecondary: Colors.white,
    tertiary: DPSGColors.lightMuted,
    onTertiary: Colors.white,
    error: DPSGColors.lightError, // #CC1F2F (OD --error)
    onError: Colors.white,
    errorContainer: DPSGColors.lightError.withValues(alpha: 0.12),
    onErrorContainer: DPSGColors.lightError,
    surface: DPSGColors.lightSurface, // #FFFFFF (OD --surface)
    onSurface: DPSGColors.lightFg, // #1C1C1E (OD --fg)
    surfaceContainerHighest: DPSGColors.lightBg, // #F5F5F7
    outline: DPSGColors.lightBorder, // #E5E5EA (OD --border)
    outlineVariant: DPSGColors.lightMuted, // #8E8E93 (OD --muted)
    scrim: DPSGColors.lightBg, // #F5F5F7 (OD --bg)
    shadow: const Color(0xFF000000).withValues(alpha: 0.12),
  ),
  scaffoldBackgroundColor: DPSGColors.lightBg, // #F5F5F7 (OD --bg)
  disabledColor: const Color.fromARGB(255, 222, 222, 222),
  inputDecorationTheme: const InputDecorationTheme(
    fillColor: Color.fromARGB(255, 242, 242, 242),
  ),
);

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
