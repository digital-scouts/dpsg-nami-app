import 'package:flutter/material.dart';

class Stufe implements Comparable<Stufe> {
  final String name;
  final Color farbe;
  final int order;
  final bool isStufeYouCanChangeTo;
  final int? alterMin;
  final int? alterMax;

  static const woelfingFarbe = Color(0xFFf56403);
  static const jungpfadfinderFarbe = Color(0xFF007bff);
  static const pfadfinderFarbe = Color(0xFF26823c);
  static const roverFarbe = Color(0xFFdc3545);
  static const leiterFarbe = Color(0xFF949494);
  static const keineStufeFarbe = Color(0xFF949494);

  static final List<Stufe> stufen = [
    Stufe("Wölfling", 1, woelfingFarbe, true, 6, 10),
    Stufe("Jungpfadfinder", 2, jungpfadfinderFarbe, true, 9, 13),
    Stufe("Pfadfinder", 3, pfadfinderFarbe, true, 12, 16),
    Stufe("Rover", 4, roverFarbe, true, 15, 20),
    Stufe("Leiter", 5, leiterFarbe, false, 18),
    Stufe("keine Stufe", 6, keineStufeFarbe),
  ];

  static Stufe? getStufeByOrder(int order) {
    return stufen.where((element) => element.order == order).firstOrNull;
  }

  static Stufe getStufeByString(String name) {
    return stufen.where((element) => element.name == name).first;
  }

  Stufe(this.name, this.order, this.farbe,
      [this.isStufeYouCanChangeTo = false, this.alterMin, this.alterMax]);

  @override
  int compareTo(Stufe other) {
    return order.compareTo(other.order);
  }
}
