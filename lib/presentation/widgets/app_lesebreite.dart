import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lesebreite fuer breite Fenster (iPad, aufgeklapptes iPhone, Split View):
/// Listen und Karten sind hoechstens [breite] breit und stehen mittig.
/// Massgeblich ist die verfuegbare Breite, nicht das Geraet. Auf dem
/// Telefon ist der zusaetzliche Rand 0.
///
/// Entscheidung: design/entscheidung/2026-10-09-responsive-lesebreite.md
class AppLesebreite extends StatelessWidget {
  const AppLesebreite({super.key, required this.builder});

  /// Hoechstbreite des Inhalts einschliesslich seines Innenabstands.
  static const double breite = 720;

  /// Zusaetzlicher Rand je Seite bei [verfuegbar] Breite.
  static double randFuer(double verfuegbar) =>
      verfuegbar.isFinite ? math.max(0, (verfuegbar - breite) / 2) : 0;

  /// Erhaelt den zusaetzlichen seitlichen Rand. Scrollende Listen addieren
  /// ihn zu ihrem Padding, damit die volle Breite scrollbar bleibt.
  final Widget Function(BuildContext context, EdgeInsets rand) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        EdgeInsets.symmetric(horizontal: randFuer(constraints.maxWidth)),
      ),
    );
  }
}

/// Begrenzt [child] mittig auf [AppLesebreite.breite], z. B. den Inhalt
/// einer vollflaechigen Titelleiste.
class AppLesebreiteBox extends StatelessWidget {
  const AppLesebreiteBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLesebreite.breite),
        child: child,
      ),
    );
  }
}
