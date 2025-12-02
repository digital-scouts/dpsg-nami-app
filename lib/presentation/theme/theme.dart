import 'package:flutter/material.dart';

/// Zentrale Farbdefinitionen der DPSG App.
/// Hinweis: Domain-Layer sollte diese Datei nicht importieren. Falls `Stufe`
/// weiter rein domain-orientiert bleiben soll, kann man alternativ ein Mapping
/// im UI Layer bereitstellen. Aktuell folgt diese Datei der Nutzeranforderung
/// direkt und liefert `Color` Konstanten.
abstract class DPSGColors {
  static const primary = Color(0xFF003056);
  static const secondary = Color(0xFF810a1a);
  static const biberFarbe = Color(0xFFFFFFFF);
  static const woelfingFarbe = Color(0xFFFF6400);
  static const jungpfadfinderFarbe = Color(0xFF2f53a7);
  static const pfadfinderFarbe = Color(0xFF00823c);
  static const roverFarbe = Color(0xFFcc1f2f);
  static const leiterFarbe = Color.fromARGB(255, 255, 247, 24);
  static const keineStufeFarbe = Colors.grey;
}

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: DPSGColors.primary,
    secondary: DPSGColors.secondary,
    brightness: Brightness.dark,
  ),
  disabledColor: const Color.fromARGB(255, 36, 36, 36),
);

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: DPSGColors.primary,
    secondary: DPSGColors.secondary,
    brightness: Brightness.light,
  ),
  disabledColor: const Color.fromARGB(255, 222, 222, 222),
);
