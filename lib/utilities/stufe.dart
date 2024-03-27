// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:nami/utilities/theme.dart';

enum Stufe implements Comparable<Stufe> {
  BIBER(
    DPSGColors.biberFarbe,
    'Biber',
    imagePath: 'assets/images/biber.png',
    isStufeYouCanChangeTo: true,
    alterMin: 4,
    alterMax: 10,
  ),
  WOELFLING(
    DPSGColors.woelfingFarbe,
    'Wölfling',
    imagePath: 'assets/images/woe.png',
    isStufeYouCanChangeTo: true,
    alterMin: 6,
    alterMax: 10,
  ),
  JUNGPADFINDER(
    DPSGColors.jungpfadfinderFarbe,
    'Jungpfadfinder',
    imagePath: 'assets/images/jufi.png',
    isStufeYouCanChangeTo: true,
    alterMin: 9,
    alterMax: 13,
  ),
  PFADFINDER(
    DPSGColors.pfadfinderFarbe,
    'Pfadfinder',
    imagePath: 'assets/images/pfadi.png',
    isStufeYouCanChangeTo: true,
    alterMin: 12,
    alterMax: 16,
  ),
  ROVER(
    DPSGColors.roverFarbe,
    'Rover',
    imagePath: 'assets/images/rover.png',
    isStufeYouCanChangeTo: true,
    alterMin: 15,
    alterMax: 20,
  ),
  LEITER(
    DPSGColors.leiterFarbe,
    'Leiter',
    imagePath: 'assets/images/lilie_schwarz.png',
    isStufeYouCanChangeTo: false,
    alterMin: 18,
  ),
  KEINE_STUFE(
    DPSGColors.keineStufeFarbe,
    'keine Stufe',
    isStufeYouCanChangeTo: false,
  );

  final Color farbe;
  final String display;
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

  static Stufe? getStufeByOrder(int order) {
    return stufen.where((element) => element.index == order).firstOrNull;
  }

  static Stufe getStufeByString(String name) {
    return stufen.where((element) => element.display == name).first;
  }

  const Stufe(
    this.farbe,
    this.display, {
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
