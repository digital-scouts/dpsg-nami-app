import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

import '../theme/theme.dart';

class StufeVisuals {
  static Color colorFor(Stufe s) => switch (s) {
    Stufe.biber => DPSGColors.biberFarbe,
    Stufe.woelfling => DPSGColors.woelfingFarbe,
    Stufe.jungpfadfinder => DPSGColors.jungpfadfinderFarbe,
    Stufe.pfadfinder => DPSGColors.pfadfinderFarbe,
    Stufe.rover => DPSGColors.roverFarbe,
    Stufe.leitung => DPSGColors.leiterFarbe,
  };

  static String assetFor(Stufe s) => switch (s) {
    Stufe.biber => 'assets/images/biber.png',
    Stufe.woelfling => 'assets/images/woe.png',
    Stufe.jungpfadfinder => 'assets/images/jufi.png',
    Stufe.pfadfinder => 'assets/images/pfadi.png',
    Stufe.rover => 'assets/images/rover.png',
    Stufe.leitung => 'assets/images/lilie_schwarz.png',
  };
}
