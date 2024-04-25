import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

class TimelineWidget extends StatelessWidget {
  final Stufe currentStufe;
  final Mitglied mitglied;
  final DateTime nextStufenwechsel;

  const TimelineWidget({
    super.key,
    required this.currentStufe,
    required this.mitglied,
    required this.nextStufenwechsel,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 10),
      painter: TimelinePainter(
        currentStufe: currentStufe,
        mitglied: mitglied,
        nextStufenwechsel: nextStufenwechsel,
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  final Stufe currentStufe;
  final Mitglied mitglied;
  final DateTime nextStufenwechsel;

  TimelinePainter({
    required this.currentStufe,
    required this.mitglied,
    required this.nextStufenwechsel,
  });

  @override
  Future<void> paint(Canvas canvas, Size size) async {
    if (currentStufe.alterMin == null || currentStufe.alterMax == null) {
      return;
    }
    DateTime birthDate = mitglied.geburtsDatum;

    // Aktuelle Stufe
    DateTime stufeStart =
        birthDate.add(Duration(days: 365 * currentStufe.alterMin!));
    DateTime stufeEnd =
        birthDate.add(Duration(days: 365 * currentStufe.alterMax!));
    final currentPaint = Paint()
      ..color = Stufe.getStufeByString(mitglied.stufe).farbe
      ..strokeWidth = 7;

    // Nächste Stufe
    Stufe? nextStufe =
        Stufe.getStufeByOrder(Stufe.getStufeByString(mitglied.stufe).index + 1);
    DateTime? nextStufeStart;
    Paint? nextPaint;
    if (nextStufe != null && nextStufe.isStufeYouCanChangeTo) {
      nextStufeStart = birthDate.add(Duration(days: 365 * nextStufe.alterMin!));
      nextPaint = Paint()
        ..color = nextStufe.farbe
        ..strokeWidth = 7;
    }
    double? nextStufeStartPos;
    if (nextStufeStart != null) {
      nextStufeStartPos = (nextStufeStart.difference(stufeStart).inDays /
              stufeEnd.difference(stufeStart).inDays) *
          size.width;
    }

    // Vorherige Stufe
    Stufe? prevStufe =
        Stufe.getStufeByOrder(Stufe.getStufeByString(mitglied.stufe).index - 1);
    DateTime? prevStufeEnd;
    Paint? prevPaint;
    if (prevStufe != null) {
      prevStufeEnd = birthDate.add(Duration(days: 365 * prevStufe.alterMax!));
      prevPaint = Paint()
        ..color = prevStufe.farbe
        ..strokeWidth = 7;
    }
    double? prevStufeEndPos;
    if (prevStufeEnd != null) {
      prevStufeEndPos = (prevStufeEnd.difference(stufeStart).inDays /
              stufeEnd.difference(stufeStart).inDays) *
          size.width;
    }

    DateTime today = DateTime.now();
    double timelineStartPos = 0;
    double timelineEndPos = size.width;
    double todayPos = (today.difference(stufeStart).inDays /
            stufeEnd.difference(stufeStart).inDays) *
        size.width;

    // Draw timeline
    if (prevStufeEndPos != null) {
      drawStripedLine(
          canvas, 0, prevStufeEndPos, size, prevPaint!, currentPaint);
    }

    canvas.drawLine(
        Offset(prevStufeEndPos ?? timelineStartPos, size.height / 2),
        Offset(nextStufeStartPos ?? timelineEndPos, size.height / 2),
        currentPaint);

    if (nextStufeStartPos != null) {
      drawStripedLine(canvas, nextStufeStartPos, timelineEndPos, size,
          nextPaint!, currentPaint);
    }

    drawArrow(todayPos, size, canvas);

    /** 
    double stufenwechselPos = (nextStufenwechsel.difference(stufeStart).inDays /
            stufeEnd.difference(stufeStart).inDays) *
        size.width;

    drawRect(stufenwechselPos, size, canvas, Colors.blueGrey, 4);
    */
  }

  void drawStripedLine(
      Canvas canvas, double start, double end, Size size, Paint p1, Paint p2) {
    double stripeLength = 3.0;
    double totalLength =
        Offset(end, size.height / 2).dx - Offset(start, size.height / 2).dx;
    double currentLength = 0.0;

    while (currentLength < totalLength) {
      double startX = Offset(start, size.height / 2).dx + currentLength;
      double endX = startX + stripeLength;

      if (endX > Offset(end, size.height / 2).dx) {
        endX = Offset(end, size.height / 2).dx;
      }

      Offset stripeStart = Offset(startX, size.height / 2);
      Offset stripeEnd = Offset(endX, size.height / 2);

      Paint paint = (currentLength / stripeLength).round() % 2 == 0 ? p1 : p2;

      canvas.drawLine(stripeStart, stripeEnd, paint);

      currentLength += stripeLength;
    }
  }

  void drawArrow(double todayPos, Size size, Canvas canvas) {
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    double triangleHeight = 7;
    double triangleCenterX = todayPos;
    double triangleCenterY = size.height / 2;

    Path path = Path();
    path.moveTo(
        triangleCenterX, triangleCenterY + triangleHeight / 3); // bottom
    path.lineTo(triangleCenterX - triangleHeight / 2,
        triangleCenterY - triangleHeight); // top left
    path.lineTo(triangleCenterX + triangleHeight / 2,
        triangleCenterY - triangleHeight); // top right
    path.close();

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, fillPaint);
  }

  void drawRect(
      double todayPos, Size size, Canvas canvas, Color color, double width) {
    final paint = Paint()..color = color;
    double barHeight = 7;
    double barX = todayPos - width / 2;
    double barY = size.height / 2 - barHeight / 2;
    canvas.drawRect(Rect.fromLTWH(barX, barY, width, barHeight), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
