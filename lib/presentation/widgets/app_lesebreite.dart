import 'package:flutter/material.dart';

/// Lesebreite fuer breite Fenster (iPad, aufgeklapptes iPhone, Split View):
/// Listen und Karten sind hoechstens [breite] breit und stehen mittig.
/// Massgeblich ist die verfuegbare Breite, nicht das Geraet. Auf dem
/// Telefon ist der zusaetzliche Rand 0.
///
/// Entscheidung: design/entscheidung/2026-10-09-responsive-lesebreite.md
class AppLesebreite extends StatelessWidget {
  const AppLesebreite({super.key, required this.builder});

  /// Hoechstbreite des Inhalts einschliesslich seines Innenabstands. So
  /// gewaehlt, dass das aufgeklappte Duo neben der Seitenleiste noch die
  /// volle Breite nutzt.
  static const double breite = 800;

  /// Mindestrand je Seite, ab dem begrenzt wird. Darunter bleiben Inhalt und
  /// Kopf randlos, damit kein schmaler Spalt entsteht.
  static const double blockRand = 24;

  /// Ob bei [verfuegbar] Breite begrenzt wird (Kopf als Block).
  static bool begrenzt(double verfuegbar) =>
      verfuegbar.isFinite && verfuegbar >= breite + 2 * blockRand;

  /// Zusaetzlicher Rand je Seite bei [verfuegbar] Breite.
  static double randFuer(double verfuegbar) =>
      begrenzt(verfuegbar) ? (verfuegbar - breite) / 2 : 0;

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
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLesebreite.randFuer(constraints.maxWidth),
        ),
        child: child,
      ),
    );
  }
}
