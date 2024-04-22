import 'package:flutter/material.dart';

const Color darkSecondary = Color(0xFF520081);

abstract class DPSGColors {
  static const primary = Color(0xFF003056);
  static const secondary = Color(0xFF810a1a);
  static const biberFarbe = Color(0xFFFFFFFF);
  static const woelfingFarbe = Color(0xFFFF6400);
  static const jungpfadfinderFarbe = Color(0xFF2f53a7);
  static const pfadfinderFarbe = Color(0xFF00823c);
  static const roverFarbe = Color(0xFFcc1f2f);
  static const leiterFarbe = Color(0xFFb1b9ad);
  static const keineStufeFarbe = DPSGColors.leiterFarbe;
}

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: DPSGColors.primary,
    secondary: DPSGColors.secondary,
    brightness: Brightness.dark,
  ),
);

//################################################################

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: DPSGColors.primary,
    secondary: DPSGColors.secondary,
    brightness: Brightness.light,
  ),
);

class ThemeModel extends ChangeNotifier {
  ThemeMode currentMode = ThemeMode.system;

  setTheme(ThemeMode type) {
    currentMode = type;
    return notifyListeners();
  }
}
