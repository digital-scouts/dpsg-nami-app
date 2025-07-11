// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nami/utilities/theme.dart';

/// Alter der Stufen wird nur noch fürs Reset in den Einstellungen verwendet.
/// Bitte nutze für alle anderen Zwecke das in der Hive gespeicherte Alter.
enum Stufe implements Comparable<Stufe> {
  BIBER(
    DPSGColors.biberFarbe,
    'Biber',
    'Biber',
    'Biber',
    imagePath: 'assets/images/biber.png',
    isStufeYouCanChangeTo: true,
    alterMin:
        4, // only inital value! Use getStufeMinAge() and getStufeMaxAge() for age boundaries
    alterMax: 7, // inital 4-6 inklusive
  ),
  WOELFLING(
    DPSGColors.woelfingFarbe,
    'Wölfling',
    'Wös',
    'Wö',
    imagePath: 'assets/images/woe.png',
    isStufeYouCanChangeTo: true,
    alterMin:
        6, // only inital value! Use getStufeMinAge() and getStufeMaxAge() for age boundaries
    alterMax: 11, // inital 6-10 inklusive
  ),
  JUNGPADFINDER(
    DPSGColors.jungpfadfinderFarbe,
    'Jungpfadfinder',
    'Jufis',
    'Jufi',
    imagePath: 'assets/images/jufi.png',
    isStufeYouCanChangeTo: true,
    alterMin:
        9, // only inital value! Use getStufeMinAge() and getStufeMaxAge() for age boundaries
    alterMax: 14, // inital 9-13 inklusive
  ),
  PFADFINDER(
    DPSGColors.pfadfinderFarbe,
    'Pfadfinder',
    'Pfadis',
    'Pfadi',
    imagePath: 'assets/images/pfadi.png',
    isStufeYouCanChangeTo: true,
    alterMin:
        12, // only inital value! Use getStufeMinAge() and getStufeMaxAge() for age boundaries
    alterMax: 17, // inital 12-16 inklusive
  ),
  ROVER(
    DPSGColors.roverFarbe,
    'Rover',
    'Rover',
    'Rover',
    imagePath: 'assets/images/rover.png',
    isStufeYouCanChangeTo: true,
    alterMin: 15,
    alterMax: 21, // 15-20 inklusive
  ),
  LEITER(
    DPSGColors.leiterFarbe,
    'Leiter:in',
    'Leiter',
    'Leiter:in',
    imagePath: 'assets/images/lilie_schwarz.png',
    isStufeYouCanChangeTo: false,
    alterMin: 18,
  ),
  KEINE_STUFE(
    DPSGColors.keineStufeFarbe,
    'keine Stufe',
    'keine Stufe',
    'keine Stufe',
    isStufeYouCanChangeTo: false,
  );

  final Color farbe;
  final String display;
  final String shortDisplay;
  final String shortDisplaySingular;
  final String? imagePath;
  final bool isStufeYouCanChangeTo;
  final int? alterMin;
  final int? alterMax;

  /// Im gegensatz zu [Stufe.values] ist hier [Stufe.KEINE_STUFE] nicht enthalten
  static const List<Stufe> stufen = [
    BIBER,
    WOELFLING,
    JUNGPADFINDER,
    PFADFINDER,
    ROVER,
    LEITER,
  ];

  /// Im gegensatz zu [Stufe.values] ist hier [Stufe.KEINE_STUFE], [Stufe.LEITER] nicht enthalten
  static const List<Stufe> stufenWithoutLeiter = [
    BIBER,
    WOELFLING,
    JUNGPADFINDER,
    PFADFINDER,
    ROVER,
  ];

  static Stufe? getStufeByOrder(int order) {
    return stufen.where((element) => element.index == order).firstOrNull;
  }

  static Stufe getStufeByString(String name) {
    return stufen.where((element) => element.display == name).firstOrNull ??
        KEINE_STUFE;
  }

  const Stufe(
    this.farbe,
    this.display,
    this.shortDisplay,
    this.shortDisplaySingular, {
    this.imagePath,
    this.isStufeYouCanChangeTo = false,
    this.alterMin,
    this.alterMax,
  });

  @override
  int compareTo(Stufe other) {
    return index.compareTo(other.index);
  }
}
