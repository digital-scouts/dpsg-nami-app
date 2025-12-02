import 'package:flutter/material.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';

import '../../domain/statistiks/group_distribution.dart';
import '../../domain/taetigkeit/stufe.dart';

/// Zeigt gestapelte Balken (Leitung unten, Mitglieder oben) für eine oder mehrere Stufen.
class GroupDistributionChart extends StatelessWidget {
  const GroupDistributionChart({
    super.key,
    required this.data,
    this.height = 220,
    this.barWidth = 32,
    this.spacing = 12,
  });
  final List<GroupDistribution> data;
  final double height;
  final double barWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxTotal = data.fold<int>(0, (m, e) => e.total > m ? e.total : m);
    if (maxTotal == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    return LayoutBuilder(
      builder: (context, constraints) {
        const axisPadding = 32.0; // Platz für Stufenlabels unten
        final availableWidth =
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width) -
            axisPadding;
        final n = data.length;
        double usedBarWidth = barWidth;
        double usedSpacing = spacing;
        if (n > 0) {
          final naturalContentWidth = n * barWidth + (n - 1) * spacing;
          if (naturalContentWidth < availableWidth) {
            final grow = availableWidth / naturalContentWidth;
            usedBarWidth = (barWidth * grow).clamp(barWidth, 56);
            usedSpacing = (spacing * grow).clamp(spacing, 24);
            var content = n * usedBarWidth + (n - 1) * usedSpacing;
            if (content > availableWidth) {
              final adjust = availableWidth / content;
              usedBarWidth = (usedBarWidth * adjust).clamp(12, 56);
              usedSpacing = (usedSpacing * adjust).clamp(2, 24);
            }
          } else if (naturalContentWidth > availableWidth) {
            final shrink = availableWidth / naturalContentWidth;
            usedBarWidth = (barWidth * shrink).clamp(8, barWidth);
            usedSpacing = (spacing * shrink).clamp(2, spacing);
          }
        }
        final totalWidth =
            axisPadding +
            (n == 0 ? 0 : n * usedBarWidth + (n - 1) * usedSpacing);
        return SizedBox(
          height: height + 48,
          width: totalWidth,
          child: CustomPaint(
            painter: _GroupDistributionPainter(
              data: data,
              maxTotal: maxTotal,
              height: height,
              barWidth: usedBarWidth,
              spacing: usedSpacing,
              textColor: textColor,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _GroupDistributionPainter extends CustomPainter {
  _GroupDistributionPainter({
    required this.data,
    required this.maxTotal,
    required this.height,
    required this.barWidth,
    required this.spacing,
    required this.textColor,
    required this.isDark,
  });
  final List<GroupDistribution> data;
  final int maxTotal;
  final double height;
  final double barWidth;
  final double spacing;
  final Color textColor;
  final bool isDark;
  static const double originX = 16;

  TextPainter _tp(
    String text, {
    double fontSize = 11,
    Color? color,
    FontWeight? fw,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color ?? textColor,
          fontWeight: fw,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: barWidth - 4);
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    double x = originX;
    for (final dist in data) {
      final totalFrac = dist.total / maxTotal;
      final totalHeight = totalFrac * height;
      final leaderFrac = dist.leitungCount / maxTotal;
      final leaderHeight = leaderFrac * height;
      final memberFrac = dist.mitgliedCount / maxTotal;
      final memberHeight = memberFrac * height;
      final leaderColor = DPSGColors.leiterFarbe;
      final memberColor = StufeVisuals.colorFor(dist.stufe);

      // Leitung Segment (unten)
      if (leaderHeight > 0) {
        final topY = height - leaderHeight;
        final rect = Rect.fromLTWH(x, topY, barWidth, leaderHeight);
        canvas.drawRect(rect, Paint()..color = leaderColor);
        final tp = _tp(
          dist.leitungCount.toString(),
          fontSize: 10,
          color: _bestTextColor(leaderColor),
        );
        final fits = leaderHeight >= tp.height + 4;
        final ty = fits
            ? topY + (leaderHeight - tp.height) / 2
            : topY - tp.height - 2;
        tp.paint(canvas, Offset(x + (barWidth - tp.width) / 2, ty));
      }

      // Mitglieder Segment (oben) mit abgerundeten Ecken
      if (memberHeight > 0) {
        final topY = height - leaderHeight - memberHeight;
        final rect = Rect.fromLTWH(x, topY, barWidth, memberHeight);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(barWidth * 0.25),
          topRight: Radius.circular(barWidth * 0.25),
        );
        canvas.drawRRect(rrect, Paint()..color = memberColor);
        // Biber-Rahmen im Light Mode
        if (dist.stufe == Stufe.biber && !isDark) {
          final borderPaint = Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
          canvas.drawRRect(rrect, borderPaint);
        }
        final tp = _tp(
          dist.mitgliedCount.toString(),
          fontSize: 10,
          color: _bestTextColor(memberColor),
        );
        final fits = memberHeight >= tp.height + 4;
        final ty = fits
            ? topY + (memberHeight - tp.height) / 2
            : topY - tp.height - 2;
        tp.paint(canvas, Offset(x + (barWidth - tp.width) / 2, ty));
      }

      // Gesamtzahl oben über dem Balken (optional wenn Platz)
      if (dist.total > 0) {
        final tpTotal = _tp(
          dist.total.toString(),
          fontSize: 11,
          fw: FontWeight.w600,
        );
        final topOfBar = height - totalHeight;
        tpTotal.paint(
          canvas,
          Offset(
            x + (barWidth - tpTotal.width) / 2,
            topOfBar - tpTotal.height - 6,
          ),
        );
      }

      // X-Achsen Label (Stufenname) unter dem Balken
      final label = _tp(dist.stufe.shortDisplayName, fontSize: 12);
      label.paint(canvas, Offset(x + (barWidth - label.width) / 2, height + 8));

      x += barWidth + spacing;
    }
  }

  Color _bestTextColor(Color bg) {
    // einfache Luma-Heuristik
    final luma = 0.299 * bg.red + 0.587 * bg.green + 0.114 * bg.blue;
    return luma > 140 ? Colors.black : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _GroupDistributionPainter old) {
    return old.data != data ||
        old.maxTotal != maxTotal ||
        old.height != height ||
        old.barWidth != barWidth ||
        old.spacing != spacing ||
        old.textColor != textColor ||
        old.isDark != isDark;
  }
}
