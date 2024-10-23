import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/stufe.dart';

class TimelineWidget extends StatelessWidget {
  final Mitglied mitglied;
  final DateTime nextStufenwechsel;

  const TimelineWidget({
    super.key,
    required this.mitglied,
    required this.nextStufenwechsel,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 10),
      painter: TimelinePainter(
        mitglied: mitglied,
        nextStufenwechsel: nextStufenwechsel,
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  final Mitglied mitglied;
  final DateTime nextStufenwechsel;

  TimelinePainter({
    required this.mitglied,
    required this.nextStufenwechsel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Stufe currentStufe = mitglied.currentStufe;
    if (getStufeMinAge(currentStufe) == null ||
        getStufeMaxAge(currentStufe) == null) {
      return;
    }

    // Aktuelle Stufe
    final DateTime stufeStart = mitglied.geburtsDatum
        .add(Duration(days: 365 * getStufeMinAge(currentStufe)!));
    final DateTime stufeEnd = mitglied.geburtsDatum
        .add(Duration(days: 365 * getStufeMaxAge(currentStufe)!));

    // Vorherige Stufe
    final Stufe? prevStufe =
        Stufe.getStufeByOrder(mitglied.currentStufe.index - 1);
    double? prevStufeEndPos;
    if (prevStufe != null) {
      DateTime prevStufeEnd = mitglied.geburtsDatum
          .add(Duration(days: 365 * getStufeMaxAge(prevStufe)!));
      prevStufeEndPos = (prevStufeEnd.difference(stufeStart).inDays /
              stufeEnd.difference(stufeStart).inDays) *
          size.width;
    }

    // Nächste Stufe
    final Stufe? nextStufe =
        Stufe.getStufeByOrder(mitglied.currentStufe.index + 1);
    double? nextStufeStartPos;
    if (nextStufe != null && nextStufe.isStufeYouCanChangeTo) {
      DateTime nextStufeStart = mitglied.geburtsDatum
          .add(Duration(days: 365 * getStufeMinAge(nextStufe)!));
      nextStufeStartPos = (nextStufeStart.difference(stufeStart).inDays /
              stufeEnd.difference(stufeStart).inDays) *
          size.width;
    }

    double timelineStartPos = 0;
    double timelineEndPos = size.width;
    double todayPos = (DateTime.now().difference(stufeStart).inDays /
            stufeEnd.difference(stufeStart).inDays) *
        size.width;

    drawLine(canvas, size, 0, timelineEndPos, currentStufe.farbe);

    // Draw timeline
    if (prevStufeEndPos != null) {
      drawOtherStufeLine(canvas, size, timelineStartPos, prevStufeEndPos,
          prevStufe!.farbe, currentStufe.farbe);
    }

    if (nextStufeStartPos != null) {
      drawOtherStufeLine(canvas, size, nextStufeStartPos, timelineEndPos,
          nextStufe!.farbe, currentStufe.farbe);
    }

    drawArrow(canvas, size, todayPos);
  }

  static void drawLine(
      Canvas canvas, Size size, double start, double end, Color color) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = 7;
    canvas.drawLine(
        Offset(start, size.height / 2), Offset(end, size.height / 2), paint);
  }

  static void drawOtherStufeLine(Canvas canvas, Size size, double start,
      double end, Color color1, Color color2) {
    const double strokeWidth = 7;
    const double yOffset = 1.5;

    final fillPaint = Paint()
      ..color = color1
      ..style = PaintingStyle.fill;
    Path path = Path();

    if (start == 0) {
      path.moveTo(start, strokeWidth + yOffset); // left bottom
      path.lineTo(start, 0 + yOffset); // left top
      path.lineTo(end, 0 + strokeWidth + yOffset); // right
    } else {
      path.moveTo(end, size.height - strokeWidth - yOffset); // right bottom
      path.lineTo(end, size.height - yOffset); // right top
      path.lineTo(start, strokeWidth + yOffset); // left
    }

    path.close();
    canvas.drawPath(path, fillPaint);
  }

  static void drawArrow(Canvas canvas, Size size, double todayPos) {
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    const double triangleHeight = 7;
    final double triangleCenterY = size.height / 2 - 2;

    Path path = Path();
    if (todayPos > size.width) {
      const double xOffset = -8;
      final double triangleCenterX = size.width;
      // Pfeil zeigt nach rechts
      path.moveTo(triangleCenterX + xOffset - triangleHeight / 2,
          triangleCenterY - triangleHeight / 2); // left
      path.lineTo(
          triangleCenterX + xOffset + triangleHeight, triangleCenterY); // right
      path.lineTo(triangleCenterX + xOffset - triangleHeight / 2,
          triangleCenterY + triangleHeight / 2); // bottom
    } else if (todayPos < 0) {
      const double xOffset = 8;
      const double triangleCenterX = 0;
      // Pfeil zeigt nach links
      path.moveTo(triangleCenterX + xOffset + triangleHeight / 2,
          triangleCenterY - triangleHeight / 2); // right
      path.lineTo(
          triangleCenterX + xOffset - triangleHeight, triangleCenterY); // left
      path.lineTo(triangleCenterX + xOffset + triangleHeight / 2,
          triangleCenterY + triangleHeight / 2); // bottom
    } else {
      final double triangleCenterX = todayPos;
      // Pfeil zeigt nach unten
      path.moveTo(
          triangleCenterX, triangleCenterY + triangleHeight / 3); // bottom
      path.lineTo(triangleCenterX - triangleHeight / 2,
          triangleCenterY - triangleHeight); // top left
      path.lineTo(triangleCenterX + triangleHeight / 2,
          triangleCenterY - triangleHeight); // top right
    }
    path.close();

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
