import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Graue Fläche mit Punkten statt einer echten Karte, z. B. für Vorschauen
/// im Katalog, Stories und Tests.
class StatistikKartenVorschau extends StatelessWidget {
  const StatistikKartenVorschau({
    super.key,
    required this.wohnorte,
    this.stammesheim,
  });

  final List<LatLng> wohnorte;
  final LatLng? stammesheim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _VorschauPainter(
        wohnorte: wohnorte,
        stammesheim: stammesheim,
        flaeche: scheme.surfaceContainerHighest,
        punkt: scheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _VorschauPainter extends CustomPainter {
  _VorschauPainter({
    required this.wohnorte,
    required this.stammesheim,
    required this.flaeche,
    required this.punkt,
  });

  final List<LatLng> wohnorte;
  final LatLng? stammesheim;
  final Color flaeche;
  final Color punkt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = flaeche);
    final alle = [...wohnorte, ?stammesheim];
    if (alle.isEmpty) return;
    final breiten = alle.map((p) => p.latitude);
    final laengen = alle.map((p) => p.longitude);
    final minB = breiten.reduce(math.min);
    final maxB = breiten.reduce(math.max);
    final minL = laengen.reduce(math.min);
    final maxL = laengen.reduce(math.max);
    Offset ort(LatLng p) => Offset(
      8 +
          (p.longitude - minL) /
              math.max(1e-9, maxL - minL) *
              (size.width - 16),
      8 +
          (maxB - p.latitude) /
              math.max(1e-9, maxB - minB) *
              (size.height - 16),
    );
    for (final p in wohnorte) {
      canvas.drawCircle(ort(p), 2.5, Paint()..color = punkt);
    }
    if (stammesheim case final heim?) {
      canvas.drawRect(
        Rect.fromCenter(center: ort(heim), width: 9, height: 9),
        Paint()..color = const Color(0xFF1565C0),
      );
    }
  }

  @override
  bool shouldRepaint(_VorschauPainter old) =>
      old.wohnorte != wohnorte ||
      old.stammesheim != stammesheim ||
      old.flaeche != flaeche ||
      old.punkt != punkt;
}
