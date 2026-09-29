import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';

import 'achievement_visuals.dart';

/// Rundes Abzeichen im Stil eines Aufnähers: Metallrand, Stoffscheibe mit
/// Naht, Motiv und Stufenpunkte. Einmalige Erfolge haben einen gewellten
/// Goldrand. Gesperrte Abzeichen sind grau, optional mit Fortschrittsring.
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.icon,
    this.tier,
    this.special = false,
    this.progress,
    this.progressTier,
    this.size = 64,
    this.semanticLabel,
  });

  factory AchievementBadge.fromProgress(
    AchievementProgress achievement, {
    Key? key,
    double size = 64,
    bool showProgress = true,
    String? semanticLabel,
  }) {
    final special = achievement.definition.isOneTime && achievement.isUnlocked;
    return AchievementBadge(
      key: key,
      icon: AchievementVisuals.iconFor(achievement.id),
      tier: achievement.currentTier,
      special: special,
      progress: showProgress && !achievement.isUnlocked
          ? achievement.progressToNext
          : null,
      progressTier: achievement.nextTier,
      size: size,
      semanticLabel: semanticLabel,
    );
  }

  final IconData icon;

  /// Erreichte Stufe. `null` und [special] = false bedeutet gesperrt.
  final AchievementTier? tier;

  /// Freigeschalteter einmaliger Erfolg.
  final bool special;

  /// Fortschritt 0..1 als Ring um das Abzeichen.
  final double? progress;

  /// Stufe, deren Farbe der Fortschrittsring trägt.
  final AchievementTier? progressTier;

  final double size;
  final String? semanticLabel;

  bool get isLocked => tier == null && !special;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = this.tier;
    final disc = special
        ? AchievementVisuals.specialDisc
        : tier != null
        ? AchievementVisuals.paletteFor(tier)
        : AchievementVisuals.lockedPalette(theme.brightness);
    final rim = special ? AchievementVisuals.specialRim : disc;
    final ringColor = progressTier != null
        ? AchievementVisuals.paletteFor(progressTier!).base
        : theme.colorScheme.primary;
    final badgeRadiusFactor = _BadgePainter.badgeRadiusFactor;

    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BadgePainter(
            rim: rim,
            disc: disc,
            level: tier == null ? 0 : tier.index + 1,
            special: special,
            flat: isLocked,
            sparkle: tier == AchievementTier.diamond,
            progress: progress,
            ringColor: ringColor,
            trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, tier != null ? -size * 0.04 : 0),
              child: Icon(
                icon,
                size: size * badgeRadiusFactor * 0.72,
                color: disc.onColor,
                shadows: disc.onColor == Colors.white
                    ? [
                        Shadow(
                          color: disc.dark.withValues(alpha: 0.6),
                          blurRadius: size * 0.03,
                          offset: Offset(0, size * 0.01),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.rim,
    required this.disc,
    required this.level,
    required this.special,
    required this.flat,
    required this.sparkle,
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  /// Radius des Abzeichens relativ zur Kantenlänge, Rest ist Platz für den
  /// Fortschrittsring.
  static const badgeRadiusFactor = 0.42;

  final AchievementPalette rim;
  final AchievementPalette disc;
  final int level;
  final bool special;

  /// Gesperrte Abzeichen: flach ohne Metallverlauf, Glanz und Schatten, damit
  /// sie sich klar von Silber abheben.
  final bool flat;
  final bool sparkle;
  final double? progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * badgeRadiusFactor;

    _paintProgressRing(canvas, center, size.shortestSide);
    _paintRim(canvas, center, r);
    _paintDisc(canvas, center, r * 0.80);
    _paintStitches(canvas, center, r * 0.70, r);
    if (level > 0) {
      _paintLevelPips(canvas, center, r);
    }
    if (sparkle) {
      _paintSparkles(canvas, center, r);
    }
  }

  void _paintProgressRing(Canvas canvas, Offset center, double side) {
    final value = progress;
    if (value == null) {
      return;
    }
    final stroke = side * 0.05;
    final radius = side / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );
    if (value <= 0) {
      return;
    }
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * value.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ringColor,
    );
  }

  void _paintRim(Canvas canvas, Offset center, double r) {
    final path = special ? _scallopPath(center, r) : _circlePath(center, r);
    final rect = Rect.fromCircle(center: center, radius: r);
    if (flat) {
      canvas.drawPath(path, Paint()..color = rim.base);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = rim.dark,
      );
      return;
    }
    canvas.drawShadow(path, Colors.black, r * 0.08, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = SweepGradient(
          transform: const GradientRotation(-pi / 4),
          colors: [
            rim.light,
            rim.base,
            rim.dark,
            rim.base,
            rim.light,
            rim.base,
            rim.dark,
            rim.base,
            rim.light,
          ],
        ).createShader(rect),
    );
  }

  void _paintDisc(Canvas canvas, Offset center, double r) {
    final rect = Rect.fromCircle(center: center, radius: r);
    if (flat) {
      canvas.drawCircle(center, r, Paint()..color = disc.light);
      return;
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [disc.light, disc.base, disc.dark],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = disc.dark.withValues(alpha: 0.55),
    );

    // Glanz auf der oberen Hälfte.
    canvas.save();
    canvas.clipPath(_circlePath(center, r));
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -r * 0.55),
        width: r * 1.7,
        height: r * 1.0,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
  }

  void _paintStitches(Canvas canvas, Offset center, double radius, double r) {
    const dashes = 32;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..strokeCap = StrokeCap.round
      ..color = disc.onColor.withValues(alpha: flat ? 0.55 : 0.4);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const step = 2 * pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.5, false, paint);
    }
  }

  void _paintLevelPips(Canvas canvas, Offset center, double r) {
    final total = AchievementTier.values.length;
    final pipRadius = r * 0.05;
    final spacing = r * 0.16;
    final y = center.dy + r * 0.46;
    final startX = center.dx - spacing * (total - 1) / 2;
    for (var i = 0; i < total; i++) {
      canvas.drawCircle(
        Offset(startX + spacing * i, y),
        pipRadius,
        Paint()
          ..color = i < level
              ? disc.onColor
              : disc.onColor.withValues(alpha: 0.22),
      );
    }
  }

  void _paintSparkles(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = Colors.white;
    for (final (angle, scale) in const [
      (-pi / 3.2, 1.0),
      (pi * 0.78, 0.7),
      (pi * 0.12, 0.55),
    ]) {
      final p = center + Offset(cos(angle), sin(angle)) * r * 0.9;
      canvas.drawPath(_sparklePath(p, r * 0.2 * scale), paint);
    }
  }

  Path _circlePath(Offset center, double r) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: r));

  Path _scallopPath(Offset center, double r) {
    const bumps = 16;
    const steps = 160;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = 2 * pi * i / steps;
      final radius = r * (0.95 + 0.05 * cos(bumps * a));
      final p = center + Offset(cos(a), sin(a)) * radius;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  Path _sparklePath(Offset c, double s) {
    final w = s * 0.22;
    return Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - s)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) =>
      old.rim != rim ||
      old.disc != disc ||
      old.level != level ||
      old.special != special ||
      old.flat != flat ||
      old.sparkle != sparkle ||
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.trackColor != trackColor;
}
