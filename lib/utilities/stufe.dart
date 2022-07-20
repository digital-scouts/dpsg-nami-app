import 'package:flutter/material.dart';

enum Stufe { woe, jufi, pfadi, rover, leiter, none }
const stufeWoeString = "Wölfling";
const stufeJufiString = 'Jungpfadfinder';
const stufePfadiString = "Pfadfinder";
const stufeRoverString = "Rover";
const stufeLeiterString = "Leiter";
const stufeNoneString = "keine Stufe";
const stufenFarbe = {
  Stufe.woe: Color(0xFFf56403),
  Stufe.jufi: Color(0xFF007bff),
  Stufe.pfadi: Color(0xFF26823c),
  Stufe.rover: Color(0xFFdc3545),
  Stufe.leiter: Color(0xFFFFD148),
  Stufe.none: Color(0xFF949494)
};

extension StufenExtension on Stufe {
  String string() {
    switch (this) {
      case Stufe.jufi:
        return stufeJufiString;
      case Stufe.leiter:
        return stufeLeiterString;
      case Stufe.rover:
        return stufeRoverString;
      case Stufe.pfadi:
        return stufePfadiString;
      case Stufe.woe:
        return stufeWoeString;
      case Stufe.none:
      default:
        return stufeNoneString;
    }
  }

  Color color() {
    switch (this) {
      case Stufe.jufi:
        return stufenFarbe[Stufe.jufi]!;
      case Stufe.leiter:
        return stufenFarbe[Stufe.leiter]!;
      case Stufe.rover:
        return stufenFarbe[Stufe.rover]!;
      case Stufe.pfadi:
        return stufenFarbe[Stufe.pfadi]!;
      case Stufe.woe:
        return stufenFarbe[Stufe.woe]!;
      case Stufe.none:
      default:
        return stufenFarbe[Stufe.none]!;
    }
  }

  static Stufe getValueFromString(String value) {
    switch (value) {
      case stufeJufiString:
        return Stufe.jufi;
      case stufeLeiterString:
        return Stufe.leiter;
      case stufePfadiString:
        return Stufe.pfadi;
      case stufeRoverString:
        return Stufe.rover;
      case stufeWoeString:
        return Stufe.woe;
      case stufeNoneString:
      default:
        return Stufe.none;
    }
  }
}
