import 'package:flutter/material.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

class StufenwechselTimeline extends StatelessWidget {
  final DateTime geburtsdatum;
  final Stufe aktuelleStufe;
  final Altersgrenzen grenzen;

  const StufenwechselTimeline({
    super.key,
    required this.geburtsdatum,
    required this.aktuelleStufe,
    required this.grenzen,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 14),
      painter: _TimelinePainter(
        geburtsdatum: geburtsdatum,
        aktuelleStufe: aktuelleStufe,
        grenzen: grenzen,
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final DateTime geburtsdatum;
  final Stufe aktuelleStufe;
  final Altersgrenzen grenzen;

  _TimelinePainter({
    required this.geburtsdatum,
    required this.aktuelleStufe,
    required this.grenzen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final current = grenzen.forStufe(aktuelleStufe);
    final currentColor = StufeVisuals.colorFor(aktuelleStufe);

    final stufeStart = geburtsdatum.add(Duration(days: 365 * current.minJahre));
    final stufeEnd = geburtsdatum.add(Duration(days: 365 * current.maxJahre));

    final prevStufe = _byOrder(aktuelleStufe.index - 1);
    final nextStufe = _byOrder(aktuelleStufe.index + 1);

    double timelineStartPos = 0;
    double timelineEndPos = size.width;

    // Basislinie der aktuellen Stufe
    _drawLine(canvas, size, timelineStartPos, timelineEndPos, currentColor);

    // Überblendung vorherige Stufe (falls überlappend)
    if (prevStufe != null) {
      final prev = grenzen.forStufe(prevStufe);
      final prevEnd = geburtsdatum.add(Duration(days: 365 * prev.maxJahre));
      if (prevEnd.isAfter(stufeStart)) {
        final prevColor = StufeVisuals.colorFor(prevStufe);
        final prevEndPos = _posBetween(
          canvas,
          size,
          stufeStart,
          stufeEnd,
          prevEnd,
        );
        _drawOverlap(canvas, size, timelineStartPos, prevEndPos, prevColor);
      }
    }

    // Überblendung nächste Stufe (falls überlappend)
    // Hinweis: Rover wechseln nicht zu Leitung → kein Verlauf/Überblendung am Ende
    if (nextStufe != null && aktuelleStufe != Stufe.rover) {
      final next = grenzen.forStufe(nextStufe);
      final nextStart = geburtsdatum.add(Duration(days: 365 * next.minJahre));
      if (nextStart.isBefore(stufeEnd)) {
        final nextColor = StufeVisuals.colorFor(nextStufe);
        final nextStartPos = _posBetween(
          canvas,
          size,
          stufeStart,
          stufeEnd,
          nextStart,
        );
        _drawOverlap(canvas, size, nextStartPos, timelineEndPos, nextColor);
      }
    }

    // Pfeil für heutige Position
    final todayPos = _posBetween(
      canvas,
      size,
      stufeStart,
      stufeEnd,
      DateTime.now(),
    );
    _drawArrow(canvas, size, todayPos);
  }

  Stufe? _byOrder(int index) {
    if (index < 0 || index >= Stufe.values.length) return null;
    return Stufe.values[index];
  }

  double _posBetween(
    Canvas canvas,
    Size size,
    DateTime start,
    DateTime end,
    DateTime point,
  ) {
    final total = end.difference(start).inDays.toDouble();
    if (total <= 0) return 0;
    final rel =
        (point.difference(start).inDays.toDouble() / total) * size.width;
    return rel;
  }

  static void _drawLine(
    Canvas canvas,
    Size size,
    double start,
    double end,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8;
    canvas.drawLine(
      Offset(start, size.height / 2),
      Offset(end, size.height / 2),
      paint,
    );
  }

  static void _drawOverlap(
    Canvas canvas,
    Size size,
    double start,
    double end,
    Color color,
  ) {
    const double strokeWidth = 8;
    const double yOffset = 3;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 1)
      ..style = PaintingStyle.fill;
    final path = Path();
    if (start == 0) {
      path.moveTo(start, strokeWidth + yOffset);
      path.lineTo(start, 0 + yOffset);
      path.lineTo(end, 0 + strokeWidth + yOffset);
    } else {
      path.moveTo(end, size.height - strokeWidth - yOffset);
      path.lineTo(end, size.height - yOffset);
      path.lineTo(start, strokeWidth + yOffset);
    }
    path.close();
    canvas.drawPath(path, fillPaint);
  }

  static void _drawArrow(Canvas canvas, Size size, double x) {
    final border = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    const double h = 8;
    final double cy = size.height / 2;
    final path = Path();
    if (x > size.width) {
      const double xOffset = -8;
      final double cx = size.width;
      path.moveTo(cx + xOffset - h / 2, cy - h / 2);
      path.lineTo(cx + xOffset + h, cy);
      path.lineTo(cx + xOffset - h / 2, cy + h / 2);
    } else if (x < 0) {
      const double xOffset = 8;
      const double cx = 0;
      path.moveTo(cx + xOffset + h / 2, cy - h / 2);
      path.lineTo(cx + xOffset - h, cy);
      path.lineTo(cx + xOffset + h / 2, cy + h / 2);
    } else {
      final double cx = x;
      path.moveTo(cx, cy + h / 3);
      path.lineTo(cx - h / 2, cy - h);
      path.lineTo(cx + h / 2, cy - h);
    }
    path.close();
    canvas.drawPath(path, border);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
