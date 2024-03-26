// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:nami/utilities/theme.dart';

enum StufeEnum {
  BIBER,
  WOELFLING,
  JUNGPADFINDER,
  PFADFINDER,
  ROVER,
  LEITER,
  KEINE_STUFE
}

extension StufeEnumExtension on StufeEnum {
  String get value {
    switch (this) {
      case StufeEnum.BIBER:
        return 'Biber';
      case StufeEnum.WOELFLING:
        return 'Wölfling';
      case StufeEnum.JUNGPADFINDER:
        return 'Jungpfadfinder';
      case StufeEnum.PFADFINDER:
        return 'Pfadfinder';
      case StufeEnum.ROVER:
        return 'Rover';
      case StufeEnum.LEITER:
        return 'Leiter';
      case StufeEnum.KEINE_STUFE:
        return 'keine Stufe';
      default:
        return '';
    }
  }
}

class Stufe implements Comparable<Stufe> {
  final StufeEnum name;
  final Color farbe;
  final int order;
  final bool isStufeYouCanChangeTo;
  final int? alterMin;
  final int? alterMax;
  final String? imageName;

  static final List<Stufe> stufen = [
    Stufe(
      StufeEnum.BIBER,
      0,
      DPSGColors.biberFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 4,
      alterMax: 10,
      imageName: 'biber.png',
    ),
    Stufe(
      StufeEnum.WOELFLING,
      1,
      DPSGColors.woelfingFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 6,
      alterMax: 10,
      imageName: 'woe.png',
    ),
    Stufe(
      StufeEnum.JUNGPADFINDER,
      2,
      DPSGColors.jungpfadfinderFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 9,
      alterMax: 13,
      imageName: 'jufi.png',
    ),
    Stufe(
      StufeEnum.PFADFINDER,
      3,
      DPSGColors.pfadfinderFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 12,
      alterMax: 16,
      imageName: 'pfadi.png',
    ),
    Stufe(
      StufeEnum.ROVER,
      4,
      DPSGColors.roverFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 15,
      alterMax: 20,
      imageName: 'rover.png',
    ),
    Stufe(
      StufeEnum.LEITER,
      5,
      DPSGColors.leiterFarbe,
      isStufeYouCanChangeTo: false,
      alterMin: 18,
      imageName: 'leiter.png',
    ),
    Stufe(StufeEnum.KEINE_STUFE, 7, DPSGColors.keineStufeFarbe),
  ];

  static Stufe? getStufeByOrder(int order) {
    return stufen.where((element) => element.order == order).firstOrNull;
  }

  static Stufe getStufeByString(String name) {
    return stufen.where((element) => element.name.value == name).first;
  }

  Stufe(
    this.name,
    this.order,
    this.farbe, {
    this.isStufeYouCanChangeTo = false,
    this.alterMin,
    this.alterMax,
    this.imageName,
  });

  @override
  int compareTo(Stufe other) {
    return order.compareTo(other.order);
  }
}
