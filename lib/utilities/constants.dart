import 'package:flutter/material.dart';

const kHintTextStyle = TextStyle(
  color: Colors.white54,
  fontFamily: 'OpenSans',
);

const kLabelStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFamily: 'OpenSans',
);

final kBoxDecorationStyle = BoxDecoration(
  color: const Color(0xFF6CA8F1),
  borderRadius: BorderRadius.circular(10.0),
  boxShadow: const [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 6.0,
      offset: Offset(0, 2),
    ),
  ],
);

enum Stufe { woe, jufi, pfadi, rover, leiter, none }
const stufeWoeString = "Wölfling";
const stufeJufiString = 'Jungpfadfinder';
const stufePfadiString = "Pfadfinder";
const stufeRoverString = "Rover";
const stufeLeiterString = "Leiter";
const stufeNoneString = "keine Stufe";

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
        return const Color(0xFF0042D1);
      case Stufe.leiter:
        return const Color(0xFFFBFF00);
      case Stufe.rover:
        return const Color(0xFFFF0000);
      case Stufe.pfadi:
        return const Color(0xFF00B609);
      case Stufe.woe:
        return const Color(0xFFEC8702);
      case Stufe.none:
      default:
        return const Color(0xFF949494);
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
