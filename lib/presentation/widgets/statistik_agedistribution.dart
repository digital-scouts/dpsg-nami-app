import 'package:flutter/material.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';

import '../../domain/statistiks/age_distribution.dart';
import '../../domain/taetigkeit/stufe.dart';

class AgeDistributionChart extends StatefulWidget {
  const AgeDistributionChart({
    super.key,
    required this.data,
    this.height = 220,
    this.barWidth = 18,
    this.spacing = 8,
    this.enableInteraction = true,
  });
  final AgeDistributionData data;
  final double height;
  final double barWidth;
  final double spacing;
  final bool enableInteraction;

  @override
  State<AgeDistributionChart> createState() => _AgeDistributionChartState();
}

class _AgeDistributionChartState extends State<AgeDistributionChart> {
  int? _hoverIndex;
  static const double _originX = 20.0; // mit Painter Origin abgestimmt

  void _updateHover(Offset localPos, double barW, double spacing) {
    final bars = widget.data.bars;
    if (bars.isEmpty) {
      if (_hoverIndex != null) setState(() => _hoverIndex = null);
      return;
    }
    final x = localPos.dx - _originX;
    if (x < 0) {
      if (_hoverIndex != null) setState(() => _hoverIndex = null);
      return;
    }
    final slot = barW + spacing;
    final idx = x ~/ slot;
    if (idx < 0 || idx >= bars.length) {
      if (_hoverIndex != null) setState(() => _hoverIndex = null);
      return;
    }
    final offsetInSlot = x - idx * slot;
    if (offsetInSlot > barW) {
      if (_hoverIndex != null) setState(() => _hoverIndex = null);
      return;
    }
    if (_hoverIndex != idx) setState(() => _hoverIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.bars.isEmpty || data.maxCount == 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const axisPadding = 60.0;
        final n = data.bars.length;
        final availableWidth =
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width) -
            axisPadding;
        double usedBarWidth = widget.barWidth;
        double usedSpacing = widget.spacing;
        if (n > 0) {
          final naturalContentWidth =
              n * widget.barWidth + (n - 1) * widget.spacing;
          if (naturalContentWidth < availableWidth) {
            final grow = availableWidth / naturalContentWidth;
            usedBarWidth = (widget.barWidth * grow).clamp(widget.barWidth, 56);
            usedSpacing = (widget.spacing * grow).clamp(widget.spacing, 24);
            var content = n * usedBarWidth + (n - 1) * usedSpacing;
            if (content > availableWidth) {
              final adjust = availableWidth / content;
              usedBarWidth = (usedBarWidth * adjust).clamp(12, 56);
              usedSpacing = (usedSpacing * adjust).clamp(2, 24);
            }
          } else if (naturalContentWidth > availableWidth) {
            final shrink = availableWidth / naturalContentWidth;
            usedBarWidth = (widget.barWidth * shrink).clamp(8, widget.barWidth);
            usedSpacing = (widget.spacing * shrink).clamp(2, widget.spacing);
          }
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final totalWidth =
            axisPadding +
            (n == 0 ? 0 : (n * usedBarWidth + (n - 1) * usedSpacing));
        Widget chart = SizedBox(
          height: widget.height + 48,
          width: totalWidth,
          child: CustomPaint(
            painter: _AgeDistributionPainter(
              data: data,
              barWidth: usedBarWidth,
              spacing: usedSpacing,
              chartHeight: widget.height,
              textColor: textColor,
              isDark: isDark,
              highlightIndex: _hoverIndex,
            ),
          ),
        );
        if (widget.enableInteraction) {
          chart = MouseRegion(
            onExit: (_) => setState(() => _hoverIndex = null),
            onHover: (e) =>
                _updateHover(e.localPosition, usedBarWidth, usedSpacing),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) =>
                  _updateHover(d.localPosition, usedBarWidth, usedSpacing),
              onPanUpdate: (d) =>
                  _updateHover(d.localPosition, usedBarWidth, usedSpacing),
              child: chart,
            ),
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            chart,
            if (_hoverIndex != null &&
                _hoverIndex! >= 0 &&
                _hoverIndex! < data.bars.length)
              _buildTooltip(
                context,
                data.bars[_hoverIndex!],
                _hoverIndex!,
                usedBarWidth,
                usedSpacing,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    AgeDistributionBar bar,
    int idx,
    double barW,
    double spacing,
  ) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surface.withValues(alpha: 0.95);
    final fg = theme.colorScheme.onSurface;
    final centerX = _originX + idx * (barW + spacing) + barW / 2;
    return Positioned(
      left: centerX - 60,
      top: 0,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alter ${bar.age}',
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
              for (final entry in bar.entries)
                Text(
                  '${entry.stufe.displayName}: ${entry.count}',
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeDistributionPainter extends CustomPainter {
  _AgeDistributionPainter({
    required this.data,
    required this.barWidth,
    required this.spacing,
    required this.chartHeight,
    required this.textColor,
    required this.isDark,
    required this.highlightIndex,
  });
  final AgeDistributionData data;
  final double barWidth;
  final double spacing;
  final double chartHeight;
  final Color textColor;
  final bool isDark;
  final int? highlightIndex;

  TextPainter textPainter(
    String text, {
    double fontSize = 10,
    Color color = Colors.black,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = textColor
      ..strokeWidth = 1;
    final origin = Offset(20, chartHeight);

    canvas.drawLine(origin, Offset(size.width, origin.dy), axisPaint);

    // Grid-Linien für jeden Schritt; Labels nur für gerade Werte
    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final maxCount = data.maxCount;
    final gridLineStep = (maxCount >= 20) ? 2 : 1; // ab 20 => jede zweite Linie
    final labelStep = (maxCount >= 40) ? 4 : 2; // ab 40 Labels alle 4

    for (int v = gridLineStep; v <= maxCount; v += gridLineStep) {
      final y = origin.dy - (v / maxCount) * chartHeight;
      _drawDashedLine(
        canvas,
        Offset(origin.dx, y),
        Offset(size.width, y),
        gridPaint,
      );
      if (v % labelStep == 0) {
        final label = textPainter(v.toString(), color: textColor);
        label.paint(
          canvas,
          Offset(origin.dx - label.width - 4, y - label.height / 2),
        );
      }
    }

    double x = origin.dx;
    for (int barIndex = 0; barIndex < data.bars.length; barIndex++) {
      final bar = data.bars[barIndex];
      final total = bar.totalCount;
      double currentBottom = origin.dy;
      for (int i = 0; i < bar.entries.length; i++) {
        final entry = bar.entries[i];
        final frac = total == 0 ? 0 : entry.count / data.maxCount;
        final h = frac * chartHeight;
        final top = currentBottom - h;
        final paint = Paint()..color = StufeVisuals.colorFor(entry.stufe);
        final rect = Rect.fromLTWH(x, top, barWidth, h);
        final isTop = i == bar.entries.length - 1;
        if (isTop) {
          final rrect = RRect.fromRectAndCorners(
            rect,
            topLeft: Radius.circular(barWidth * 0.25),
            topRight: Radius.circular(barWidth * 0.25),
          );
          canvas.drawRRect(rrect, paint);
          // Rand für Biber im Light Mode
          if (entry.stufe == Stufe.biber && !isDark) {
            final borderPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5;
            canvas.drawRRect(rrect, borderPaint);
          }
        } else {
          canvas.drawRect(rect, paint);
          if (entry.stufe == Stufe.biber && !isDark) {
            final borderPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5;
            canvas.drawRect(rect, borderPaint);
          }
        }
        currentBottom -= h;
      }
      final ageLabel = textPainter(bar.age.toString(), color: textColor);
      ageLabel.paint(
        canvas,
        Offset(x + (barWidth - ageLabel.width) / 2, origin.dy + 4),
      );
      if (highlightIndex == barIndex) {
        final barTop = origin.dy - (total / data.maxCount) * chartHeight;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, barTop, barWidth, origin.dy - barTop),
          topLeft: Radius.circular(barWidth * 0.25),
          topRight: Radius.circular(barWidth * 0.25),
        );
        final hlPaint = Paint()
          ..color = textColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rect, hlPaint);
      }
      x += barWidth + spacing;
    }

    // X-Achsen Titel
    final xTitle = textPainter('Alter', fontSize: 12, color: textColor);
    xTitle.paint(
      canvas,
      Offset(size.width / 2 - xTitle.width / 2, origin.dy + 24),
    );
  }

  @override
  bool shouldRepaint(covariant _AgeDistributionPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.spacing != spacing ||
        oldDelegate.chartHeight != chartHeight ||
        oldDelegate.textColor != textColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.highlightIndex != highlightIndex;
  }
}

void _drawDashedLine(
  Canvas canvas,
  Offset p1,
  Offset p2,
  Paint paint, {
  double dashLength = 6,
  double gap = 4,
}) {
  final total = (p2 - p1).distance;
  final dir = (p2 - p1) / total;
  double drawn = 0;
  while (drawn < total) {
    final start = p1 + dir * drawn;
    final end = p1 + dir * (drawn + dashLength).clamp(0, total);
    canvas.drawLine(start, end, paint);
    drawn += dashLength + gap;
  }
}
