import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_bewegung.dart';

/// Person aus dem Logo, die auf der Startbühne ihr Halstuch knotet (#279,
/// `design/entscheidung/2026-10-30-startbuehne.md`).
///
/// Gezeichnet statt als Bild geladen, damit sie schon im ersten Frame steht
/// und pixelgleich das native Startbild übernimmt. Die Maße folgen
/// `design/marke/lib/marke.mjs` (Ausschnitt 26 16,75 48 48, senkrecht auf die
/// Person zentriert; Hals bei 50/40,6);
/// Änderungen dort hier nachziehen und die Startbilder neu exportieren.
///
/// [knoten] läuft von 0 (ohne Tuch, wie das native Bild) bis 1 (geknotet).
/// Mit [blende] erscheint das fertige Tuch nur als Überblendung, etwa bei
/// reduzierter Bewegung oder wenn der Inhalt schnell bereit ist.
class StartbuehnePerson extends StatelessWidget {
  const StartbuehnePerson({
    super.key,
    required this.knoten,
    this.blende,
    this.groesse = groesseStandard,
  });

  final Animation<double> knoten;
  final Animation<double>? blende;
  final double groesse;

  /// Größe auf der Bühne und im nativen Startbild (160 pt).
  static const double groesseStandard = 160;

  /// Gesamtdauer des Knotens, etwa 0,6 s.
  static const Duration dauer = Duration(milliseconds: 520);

  @override
  Widget build(BuildContext context) {
    final blende = this.blende;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: groesse,
        child: CustomPaint(
          key: const Key('startbuehne-person'),
          painter: _PersonMaler(knoten: knoten, blende: blende),
        ),
      ),
    );
  }
}

/// Zeitplan des Knotens in Millisekunden ab Start.
abstract final class _Plan {
  static const double gesamt = 520;
  // Tuch legt sich: Fade und Scale 0,96 → 1.
  static const double tuchBis = 220;
  // Ring schiebt sich von unten hoch und federt ein.
  static const double ringAb = 120;
  static const double ring = 320;
  // Zipfel gehen bei 40 % des Rings auf.
  static const double zipfelAb = ringAb + 0.4 * ring;
  static const double zipfel = 260;
}

final Curve _ringFeder = FederKurve(
  SpringDescription.withDurationAndBounce(
    duration: Duration(milliseconds: _Plan.ring.round()),
    bounce: 0.15,
  ),
  dauer: Duration(milliseconds: _Plan.ring.round()),
);

class _Knotenstand {
  const _Knotenstand({
    required this.tuchDeckkraft,
    required this.tuchSkala,
    required this.zipfelWinkel,
    required this.ringDeckkraft,
    required this.ringVersatz,
  });

  factory _Knotenstand.ausAnimation(double t) {
    final ms = t * _Plan.gesamt;
    double abschnitt(double ab, double dauer) =>
        ((ms - ab) / dauer).clamp(0.0, 1.0);
    final tuch = AppBewegung.ausgang.transform(abschnitt(0, _Plan.tuchBis));
    final ringT = abschnitt(_Plan.ringAb, _Plan.ring);
    final zipfel = AppBewegung.bewegung.transform(
      abschnitt(_Plan.zipfelAb, _Plan.zipfel),
    );
    return _Knotenstand(
      tuchDeckkraft: tuch,
      tuchSkala: 0.96 + 0.04 * tuch,
      zipfelWinkel: 18 * (1 - zipfel),
      ringDeckkraft: (ringT / 0.12).clamp(0.0, 1.0),
      ringVersatz: 8 * (1 - _ringFeder.transform(ringT)),
    );
  }

  factory _Knotenstand.geblendet(double deckkraft) => _Knotenstand(
    tuchDeckkraft: deckkraft,
    tuchSkala: 1,
    zipfelWinkel: 0,
    ringDeckkraft: deckkraft,
    ringVersatz: 0,
  );

  final double tuchDeckkraft;
  final double tuchSkala;
  final double zipfelWinkel;
  final double ringDeckkraft;
  final double ringVersatz;
}

class _PersonMaler extends CustomPainter {
  _PersonMaler({required this.knoten, this.blende})
    : super(repaint: blende ?? knoten);

  final Animation<double> knoten;
  final Animation<double>? blende;

  _Knotenstand get stand {
    final blende = this.blende;
    return blende == null
        ? _Knotenstand.ausAnimation(knoten.value)
        : _Knotenstand.geblendet(blende.value);
  }

  static const _linie = Color(0xFFFFFFFF);
  static const _tuch = Color(0xFFB9B9B9);
  static const _leder = Color(0xFFA8744A);

  // Hals auf Schulterhöhe und Lage der Teile in viewBox-Einheiten.
  static const double _cx = 50;
  static const double _hals = 40.6;

  @override
  void paint(Canvas canvas, Size size) {
    final stand = this.stand;
    canvas
      ..save()
      ..scale(size.width / 48)
      ..translate(-26, -16.75);
    _umriss(canvas);
    if (stand.tuchDeckkraft > 0) {
      _halstuch(canvas, stand);
    }
    canvas.restore();
  }

  void _umriss(Canvas canvas) {
    final stift = Paint()
      ..color = _linie
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(_cx, 26), 7.5, stift);
    final schulter = Path()
      ..moveTo(34, 62.85)
      ..lineTo(34, 53)
      ..quadraticBezierTo(34, 40, _cx, 40)
      ..quadraticBezierTo(66, 40, 66, 53)
      ..lineTo(66, 62.85);
    canvas.drawPath(schulter, stift);
  }

  void _halstuch(Canvas canvas, _Knotenstand stand) {
    final tuch = Paint()
      ..color = _tuch.withValues(alpha: stand.tuchDeckkraft)
      ..style = PaintingStyle.fill;
    final rand = Paint()
      ..color = tuch.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeJoin = StrokeJoin.round;
    void flaeche(Path p) => canvas
      ..drawPath(p, tuch)
      ..drawPath(p, rand);

    // Zipfel drehen um ihren oberen inneren Rand.
    for (final seite in const [1.0, -1.0]) {
      final drehpunkt = Offset(_cx - seite, _hals + 9.6);
      canvas
        ..save()
        ..translate(drehpunkt.dx, drehpunkt.dy)
        ..rotate(-seite * stand.zipfelWinkel * math.pi / 180)
        ..translate(-drehpunkt.dx, -drehpunkt.dy);
      flaeche(
        Path()
          ..moveTo(_x(-1.6 * seite), _y(9.6))
          ..lineTo(_x(-0.1 * seite), _y(9.6))
          ..lineTo(_x(-4 * seite), _y(17.2))
          ..close(),
      );
      canvas.restore();
    }

    canvas
      ..save()
      ..translate(_cx, _hals + 6)
      ..scale(stand.tuchSkala)
      ..translate(-_cx, -(_hals + 6));
    flaeche(_band(1)..addPath(_band(-1), Offset.zero));
    // Tuch unter dem Ring, sanft in die Zipfel eingezogen (W2).
    flaeche(
      Path()
        ..moveTo(_x(-1.9), _y(6))
        ..quadraticBezierTo(_x(-1.5), _y(7.9), _x(-1.6), _y(9.8))
        ..lineTo(_x(1.6), _y(9.8))
        ..quadraticBezierTo(_x(1.5), _y(7.9), _x(1.9), _y(6))
        ..close(),
    );
    canvas.restore();

    if (stand.ringDeckkraft > 0) {
      canvas
        ..save()
        ..translate(0, stand.ringVersatz);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_cx - 2.4, _hals + 5, 4.8, 5.2),
          const Radius.circular(2),
        ),
        Paint()..color = _leder.withValues(alpha: stand.ringDeckkraft),
      );
      final rillen = Paint()
        ..color = _linie.withValues(alpha: 0.35 * stand.ringDeckkraft)
        ..strokeWidth = 0.45;
      for (final dy in const [6.7, 8.4]) {
        canvas.drawLine(
          Offset(_x(-1.7), _y(dy)),
          Offset(_x(1.7), _y(dy)),
          rillen,
        );
      }
      canvas.restore();
    }
  }

  // Band über die Schulter: Oberkante bündig auf der Außenkante der
  // Schulterlinie (S2), dann in den Ring.
  Path _band(double seite) {
    double kurve(double x) {
      final t = math.sqrt(1 - x / 16);
      return 13 * math.pow(1 - t, 2) - 0.6 - 1.9;
    }

    const aussen = 10.6;
    const innen = 4.4;
    final p = Path()..moveTo(_x(-aussen * seite), _y(kurve(aussen)));
    for (var i = 1; i <= 6; i++) {
      final x = aussen - (aussen - innen) * i / 6;
      p.lineTo(_x(-x * seite), _y(kurve(x)));
    }
    return p
      ..quadraticBezierTo(_x(-2.4 * seite), _y(2.6), _x(-0.15 * seite), _y(5.6))
      ..lineTo(_x(-1.9 * seite), _y(6))
      ..quadraticBezierTo(
        _x(-8.6 * seite),
        _y(4.6),
        _x(-aussen * seite),
        _y(kurve(aussen)),
      )
      ..close();
  }

  static double _x(double dx) => _cx + dx;
  static double _y(double dy) => _hals + dy;

  @override
  bool shouldRepaint(covariant _PersonMaler oldDelegate) =>
      oldDelegate.knoten != knoten || oldDelegate.blende != blende;
}
