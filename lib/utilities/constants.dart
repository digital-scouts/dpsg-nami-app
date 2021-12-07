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

  MaterialColor color() {
    switch (this) {
      case Stufe.jufi:
        return Colors.blue;
      case Stufe.leiter:
        return Colors.yellow;
      case Stufe.rover:
        return Colors.red;
      case Stufe.pfadi:
        return Colors.green;
      case Stufe.woe:
        return Colors.orange;
      case Stufe.none:
      default:
        return Colors.grey;
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
