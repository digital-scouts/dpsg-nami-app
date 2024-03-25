// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

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

  static const biberFarbe = Color(0xFFFFFFFF);
  static const woelfingFarbe = Color(0xFFf56403);
  static const jungpfadfinderFarbe = Color(0xFF007bff);
  static const pfadfinderFarbe = Color(0xFF26823c);
  static const roverFarbe = Color(0xFFdc3545);
  static const leiterFarbe = Color(0xFF949494);
  static const keineStufeFarbe = Color(0xFF949494);

  static final List<Stufe> stufen = [
    Stufe(
      StufeEnum.BIBER,
      0,
      woelfingFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 4,
      alterMax: 10,
      imageName: 'biber.png',
    ),
    Stufe(
      StufeEnum.WOELFLING,
      1,
      woelfingFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 6,
      alterMax: 10,
      imageName: 'woe.png',
    ),
    Stufe(
      StufeEnum.JUNGPADFINDER,
      2,
      jungpfadfinderFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 9,
      alterMax: 13,
      imageName: 'jufi.png',
    ),
    Stufe(
      StufeEnum.PFADFINDER,
      3,
      pfadfinderFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 12,
      alterMax: 16,
      imageName: 'pfadi.png',
    ),
    Stufe(
      StufeEnum.ROVER,
      4,
      roverFarbe,
      isStufeYouCanChangeTo: true,
      alterMin: 15,
      alterMax: 20,
      imageName: 'rover.png',
    ),
    Stufe(
      StufeEnum.LEITER,
      5,
      leiterFarbe,
      isStufeYouCanChangeTo: false,
      alterMin: 18,
      imageName: 'leiter.png',
    ),
    Stufe(StufeEnum.KEINE_STUFE, 7, keineStufeFarbe),
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
