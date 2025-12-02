import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/domain/member/taetigkeit.dart';
import 'package:nami/domain/member/taetigkeit_statistik.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MemberRolesStatistikPie extends StatelessWidget {
  const MemberRolesStatistikPie({
    super.key,
    required this.roles,
    this.size = 180,
  });

  final List<Taetigkeit> roles;
  final double size;

  @override
  Widget build(BuildContext context) {
    final durations = durationsByRoleDays(roles);
    if (durations.isEmpty) return const SizedBox.shrink();

    final slices = durations.where((d) => d.days > 0).toList();
    if (slices.isEmpty) return const SizedBox.shrink();

    // Wenn alle Slices dieselbe Stufe (Farbe) hätten: leerer Container
    final distinctStufen = slices.map((s) => s.stufe).toSet();
    if (distinctStufen.length <= 1) return const SizedBox.shrink();

    // Sortierung: Leitung vor Mitglied, Sonstiges am Ende, dann Stufe
    slices.sort((a, b) {
      int prioA = a.art == TaetigkeitsArt.leitung
          ? 2
          : (a.art == TaetigkeitsArt.mitglied ? 1 : 0);
      int prioB = b.art == TaetigkeitsArt.leitung
          ? 2
          : (b.art == TaetigkeitsArt.mitglied ? 1 : 0);
      if (prioA != prioB) return prioB.compareTo(prioA);
      return a.stufe.index.compareTo(b.stufe.index);
    });

    final totalDays = slices.fold<int>(0, (sum, e) => sum + e.days);
    if (totalDays <= 0) return const SizedBox.shrink();

    final sections = <_PieSection>[];
    double startAngle = -math.pi / 2; // Start oben
    for (final s in slices) {
      final fraction = s.days / totalDays;
      final sweep = fraction * 2 * math.pi;
      sections.add(
        _PieSection(
          startAngle: startAngle,
          sweepAngle: sweep,
          color: s.stufe.color,
          roleKey: _RoleKey(s.stufe, s.art),
          fraction: fraction,
        ),
      );
      startAngle += sweep;
    }

    final radius = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _PiePainter(sections: sections),
          ),
          // Badges auf die Slices legen
          for (final s in sections) _buildBadgeForSection(context, s, radius),
        ],
      ),
    );
  }

  Widget _buildBadgeForSection(
    BuildContext context,
    _PieSection s,
    double radius,
  ) {
    final midAngle = s.startAngle + s.sweepAngle / 2;
    final badgeRadius = radius * 0.7;
    final cx = radius + badgeRadius * math.cos(midAngle);
    final cy = radius + badgeRadius * math.sin(midAngle);

    final isLeitung = s.roleKey.art == TaetigkeitsArt.leitung;
    final badgeSize = 26.0;

    // Spezialfall: Biber Leitung – Kreis wie üblich, aber Lilie aus SVG (für Outline).
    final useSvgLilie = isLeitung && s.roleKey.stufe == Stufe.biber;

    final String asset = useSvgLilie
        ? 'assets/images/lilie.svg'
        : (isLeitung ? Stufe.leitung.imagePath : s.roleKey.stufe.imagePath);
    // Bei Biber Leitung kein Tint anwenden, damit schwarzer Outline erhalten bleibt und Fill weiß bleibt.
    final Color? tint = (useSvgLilie
        ? null
        : (isLeitung ? s.roleKey.stufe.color : null));

    return Positioned(
      left: cx - badgeSize / 2,
      top: cy - badgeSize / 2,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2.0),
        child: useSvgLilie
            ? SvgPicture.asset(
                asset,
                width: badgeSize,
                height: badgeSize,
                fit: BoxFit.contain,
                colorFilter: tint != null
                    ? ColorFilter.mode(tint, BlendMode.srcIn)
                    : null,
              )
            : Image.asset(
                asset,
                color: tint,
                colorBlendMode: tint != null ? BlendMode.srcIn : null,
              ),
      ),
    );
  }
}

class _RoleKey {
  const _RoleKey(this.stufe, this.art);
  final Stufe stufe;
  final TaetigkeitsArt art;

  @override
  bool operator ==(Object other) {
    return other is _RoleKey && other.stufe == stufe && other.art == art;
  }

  @override
  int get hashCode => Object.hash(stufe, art);
}

class _PieSection {
  _PieSection({
    required this.startAngle,
    required this.sweepAngle,
    required this.color,
    required this.roleKey,
    required this.fraction,
  });
  final double startAngle;
  final double sweepAngle;
  final Color color;
  final _RoleKey roleKey;
  final double fraction;
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.sections});
  final List<_PieSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2;
    final innerR = 0.0; // Donut-Stil
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in sections) {
      paint.color = s.color;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          s.startAngle,
          s.sweepAngle,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          s.startAngle + s.sweepAngle,
          -s.sweepAngle,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.sections != sections;
  }
}
