import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Gemeinsame Kurven und Dauern für Bewegung in der App (#278).
///
/// Bei „Bewegung reduzieren“ entfallen Lage-, Größen- und Gleitbewegungen;
/// Deckkraft und Farbe bleiben, weil sie beim Verstehen helfen. Für Lage und
/// Größe deshalb [lage] statt einer festen Dauer verwenden.
abstract final class AppBewegung {
  /// Ein- und Ausblenden, Antwort auf eine Eingabe: startet schnell.
  static const Curve ausgang = Cubic(0.23, 1, 0.32, 1);

  /// Bewegung und Formwechsel auf dem Bildschirm.
  static const Curve bewegung = Cubic(0.77, 0, 0.175, 1);

  /// Flächen und Sheets, die hereingleiten (iOS-Schubladenkurve).
  static const Curve blatt = Cubic(0.32, 0.72, 0, 1);

  /// Rückmeldung auf Druck, z. B. Auswahl einer Filterfläche.
  static const Duration druck = Duration(milliseconds: 120);

  /// Kleine Übergänge wie Hervorhebungen oder Inhaltswechsel.
  static const Duration klein = Duration(milliseconds: 180);

  /// Dialoge und Seitenwechsel innerhalb einer Fläche.
  static const Duration standard = Duration(milliseconds: 250);

  /// Große Flächen, die hereinkommen oder gehen.
  static const Duration gross = Duration(milliseconds: 350);

  /// Standardfeder ohne Überschwingen.
  static final SpringDescription feder =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 400),
      );

  /// Ob das System „Bewegung reduzieren“ meldet.
  static bool reduziert(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Dauer für Lage- und Größenbewegung; bei reduzierter Bewegung sofort.
  static Duration lage(BuildContext context, Duration dauer) =>
      reduziert(context) ? Duration.zero : dauer;
}

/// Kurve aus einer Feder für Tween-Animationen. Die Animation sollte [dauer]
/// dauern, damit die Feder bis zum Ende eingeschwungen ist. Die Werte dürfen
/// über 1 hinausgehen.
class FederKurve extends Curve {
  FederKurve(SpringDescription feder, {required this.dauer})
    : _simulation = SpringSimulation(feder, 0, 1, 0);

  final Duration dauer;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) =>
      _simulation.x(t * dauer.inMicroseconds / Duration.microsecondsPerSecond);
}
