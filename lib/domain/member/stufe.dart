import 'package:flutter/material.dart';
import '../../presentation/theme/theme.dart';

enum Stufe { biber, woelfling, jungpfadfinder, pfadfinder, rover, leitung }

extension StufeProps on Stufe {
  /// Anzeigename (lokalisiert später via I18n Layer)
  String get displayName => switch (this) {
    Stufe.biber => 'Biber',
    Stufe.woelfling => 'Wölfling',
    Stufe.jungpfadfinder => 'Jungpfadfinder',
    Stufe.pfadfinder => 'Pfadfinder',
    Stufe.rover => 'Rover',
    Stufe.leitung => 'Leitung',
  };

  String get shortDisplayName => switch (this) {
    Stufe.biber => 'Biber',
    Stufe.woelfling => 'Wö',
    Stufe.jungpfadfinder => 'Jufi',
    Stufe.pfadfinder => 'Pfadi',
    Stufe.rover => 'Rover',
    Stufe.leitung => 'Leitung',
  };

  /// Primärfarbe als direkte `Color` aus dem zentralen Theme.
  Color get color => switch (this) {
    Stufe.biber => DPSGColors.biberFarbe,
    Stufe.woelfling => DPSGColors.woelfingFarbe,
    Stufe.jungpfadfinder => DPSGColors.jungpfadfinderFarbe,
    Stufe.pfadfinder => DPSGColors.pfadfinderFarbe,
    Stufe.rover => DPSGColors.roverFarbe,
    Stufe.leitung => DPSGColors.leiterFarbe,
  };

  /// Relativer Asset-Pfad (später durch Asset-Konvention im UI geladen).
  String get imagePath => switch (this) {
    Stufe.biber => 'assets/images/biber.png',
    Stufe.woelfling => 'assets/images/woe.png',
    Stufe.jungpfadfinder => 'assets/images/jufi.png',
    Stufe.pfadfinder => 'assets/images/pfadi.png',
    Stufe.rover => 'assets/images/rover.png',
    Stufe.leitung => 'assets/images/lilie_schwarz.png',
  };

  num get order => switch (this) {
    Stufe.biber => 1,
    Stufe.woelfling => 2,
    Stufe.jungpfadfinder => 3,
    Stufe.pfadfinder => 4,
    Stufe.rover => 5,
    Stufe.leitung => 6,
  };

  num get defaultMinAge => switch (this) {
    Stufe.biber => 4,
    Stufe.woelfling => 6,
    Stufe.jungpfadfinder => 9,
    Stufe.pfadfinder => 12,
    Stufe.rover => 15,
    Stufe.leitung => 18,
  };

  num get defaultMaxAge => switch (this) {
    Stufe.biber => 7,
    Stufe.woelfling => 11,
    Stufe.jungpfadfinder => 14,
    Stufe.pfadfinder => 17,
    Stufe.rover => 21,
    Stufe.leitung => 99,
  };
}
