import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/appearance/appearance_catalog.dart';

/// Zeichnet die animierten Header-Hintergruende. Portiert aus
/// design/supporter/lib/backgrounds.mjs: gleiche Szenen, Farben und Zeiten.
/// Die Szene ist fuer 1200 x 400 entworfen und wird unten buendig
/// beschnitten (wie `preserveAspectRatio="xMidYMax slice"`).
class SupporterBackgroundPainter extends CustomPainter {
  SupporterBackgroundPainter({
    required this.background,
    required this.dark,
    required this.seconds,
  });

  final AppearanceBackgroundId background;
  final bool dark;

  /// Laufzeit der Animation in Sekunden.
  final double seconds;

  static const double designWidth = 1200;
  static const double designHeight = 400;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(
      size.width / designWidth,
      size.height / designHeight,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - designWidth * scale) / 2,
      size.height - designHeight * scale,
    );
    canvas.scale(scale);
    final scene = _Scene(canvas, seconds);
    switch (background) {
      case AppearanceBackgroundId.lagerfeuer:
        dark ? scene.lagerfeuerNacht() : scene.lagerfeuerTag();
      case AppearanceBackgroundId.himmel:
        dark ? scene.himmelNacht() : scene.himmelTag();
      case AppearanceBackgroundId.wald:
        dark ? scene.waldNacht() : scene.waldTag();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SupporterBackgroundPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.background != background ||
      oldDelegate.dark != dark;
}

const double _w = SupporterBackgroundPainter.designWidth;
const double _h = SupporterBackgroundPainter.designHeight;

// ------------------------------------------------------------------ Farben

class _Colors {
  // Lagerfeuer
  static const lfDayTop = Color(0xFFE6EDF0);
  static const lfDayBottom = Color(0xFFF3E6D6);
  static const lfDayHill = Color(0xFFD8C7AE);
  static const lfDayTrees = Color(0xFFB9B08F);
  static const lfDaySmoke = Color(0xFF8F877F);
  static const lfDayLog = Color(0xFF8A6A52);
  static const lfDayEmber = Color(0xFFE98A4A);
  static const lfDayBird = Color(0xFF56606A);
  static const lfNightTop = Color(0xFF1D1512);
  static const lfNightBottom = Color(0xFF3A241B);
  static const lfNightHill = Color(0xFF2C1C16);
  static const lfNightTrees = Color(0xFF24170F);
  static const lfNightGlow = Color(0xFFE07A3C);
  static const lfNightSpark = Color(0xFFFFB56B);
  // Himmel
  static const hDayTop = Color(0xFFB7D0E6);
  static const hDayBottom = Color(0xFFEEF2EE);
  static const hDayHill = Color(0xFFBCCBC2);
  static const hDayTrees = Color(0xFF9FB3A6);
  static const hDayCloud = Color(0xFFFFFFFF);
  static const hDayBird = Color(0xFF4D5A66);
  static const hNightTop = Color(0xFF0B1428);
  static const hNightBottom = Color(0xFF1D2F50);
  static const hNightHill = Color(0xFF15223B);
  static const hNightTrees = Color(0xFF0F1A2E);
  static const hNightStar = Color(0xFFE6ECF7);
  // Wald
  static const wDayTop = Color(0xFFE3EBE2);
  static const wDayBottom = Color(0xFFCFDCCD);
  static const wDayFar = Color(0xFFB9CBB8);
  static const wDayMid = Color(0xFF9FB69F);
  static const wDayNear = Color(0xFF85A086);
  static const wDayFog = Color(0xFFF4F7F2);
  static const wDayRay = Color(0xFFFFF6D6);
  static const wDayFly = Color(0xFF4E6660);
  static const wNightTop = Color(0xFF0D1612);
  static const wNightBottom = Color(0xFF16241D);
  static const wNightFar = Color(0xFF1B2C23);
  static const wNightMid = Color(0xFF16251D);
  static const wNightNear = Color(0xFF101C16);
  static const wNightFog = Color(0xFF6D8A7A);
  static const wNightBug = Color(0xFFF4E79A);
}

// ------------------------------------------------------------ Hilfsmittel

/// mulberry32, identisch zur JS-Vorlage, damit die Szenen gleich aussehen.
class _Rng {
  _Rng(int seed) : _a = seed & 0xFFFFFFFF;

  int _a;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}

double _fract(double v) => v - v.floorToDouble();

/// Phase 0..1 einer Endlos-Animation; `delay` wie CSS (negativ = Vorlauf).
double _phase(double t, double duration, [double delay = 0]) =>
    _fract((t - delay) / duration);

/// Hin und her (CSS `alternate`), mit ease-in-out.
double _alternate(double t, double duration, [double delay = 0]) {
  final p = _fract((t - delay) / (duration * 2)) * 2;
  final linear = p <= 1 ? p : 2 - p;
  return Curves.easeInOut.transform(linear);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Wert aus Keyframes (Position 0..1 -> Wert), je Segment mit `curve`.
double _keyframes(
  double p,
  List<(double, double)> frames, [
  Curve curve = Curves.linear,
]) {
  for (var i = 0; i < frames.length - 1; i++) {
    final (p0, v0) = frames[i];
    final (p1, v1) = frames[i + 1];
    if (p <= p1) {
      final local = p1 == p0 ? 1.0 : ((p - p0) / (p1 - p0)).clamp(0.0, 1.0);
      return _lerp(v0, v1, curve.transform(local));
    }
  }
  return frames.last.$2;
}

Path _smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = i == 0 ? points[i] : points[i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = i + 2 < points.length ? points[i + 2] : p2;
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6,
      p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6,
      p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx,
      p2.dy,
    );
  }
  return path;
}

Path _ridge({
  required double y,
  required double amp,
  required int seed,
  int steps = 7,
}) {
  final rand = _Rng(seed);
  final points = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    points.add(Offset(i / steps * _w, y + (rand.next() - 0.5) * 2 * amp));
  }
  final path = _smoothPath([
    Offset(-40, points.first.dy),
    ...points,
    Offset(_w + 40, points.last.dy),
  ]);
  return path
    ..lineTo(_w + 40, _h)
    ..lineTo(-40, _h)
    ..close();
}

void _addPine(Path path, double x, double by, double h) {
  path.addRect(Rect.fromLTRB(x - h * 0.025, by - h * 0.12, x + h * 0.025, by));
  for (var i = 0; i < 4; i++) {
    final top = by - h + i * h * 0.2;
    final bottom = top + h * 0.34;
    final hw = h * (0.1 + i * 0.065);
    path
      ..moveTo(x, top)
      ..lineTo(x + hw, bottom)
      ..quadraticBezierTo(x, bottom - h * 0.05, x - hw, bottom)
      ..close();
  }
}

Path _pineRow({
  required double from,
  required double to,
  required double y,
  required double hMin,
  required double hMax,
  required int seed,
  double gap = 0.55,
}) {
  final rand = _Rng(seed);
  final path = Path();
  var x = from;
  while (x < to) {
    final h = hMin + rand.next() * (hMax - hMin);
    _addPine(path, x, y + rand.next() * 14, h);
    x += h * (gap * 0.6 + rand.next() * gap * 0.5);
  }
  return path;
}

/// Statische Geometrie wird einmal berechnet und wiederverwendet.
final Map<String, Path> _pathCache = {};

Path _cached(String key, Path Function() build) =>
    _pathCache.putIfAbsent(key, build);

// ------------------------------------------------------------------ Szenen

class _Scene {
  _Scene(this.canvas, this.t);

  final Canvas canvas;
  final double t;

  Paint _fill(Color color, [double opacity = 1]) => Paint()
    ..color = color.withValues(alpha: color.a * opacity)
    ..isAntiAlias = true;

  void _sky(Color top, Color bottom) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _h), [
          top,
          bottom,
        ]),
    );
  }

  void _path(String key, Path Function() build, Color color) =>
      canvas.drawPath(_cached(key, build), _fill(color));

  void _hillsAndCampTrees(String prefix, Color hill, Color trees) {
    _path('$prefix.ridge', () => _ridge(y: 300, amp: 22, seed: 3), hill);
    _path(
      '$prefix.treesLeft',
      () => _pineRow(from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4),
      trees,
    );
    _path(
      '$prefix.treesRight',
      () => _pineRow(from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5),
      trees,
    );
  }

  void _skyline(String prefix, Color hill, Color trees) {
    _path('$prefix.ridge', () => _ridge(y: 330, amp: 26, seed: 8), hill);
    _path(
      '$prefix.trees',
      () => _pineRow(
        from: -20,
        to: 1220,
        y: 380,
        hMin: 50,
        hMax: 90,
        seed: 9,
        gap: 0.9,
      ),
      trees,
    );
  }

  // ---------------------------------------------------------- Lagerfeuer

  void lagerfeuerTag() {
    _sky(_Colors.lfDayTop, _Colors.lfDayBottom);
    _birds(const [
      _Flock(y: 90, dir: 1, duration: 46, delay: -8, count: 3),
      _Flock(y: 150, dir: -1, duration: 58, delay: -30, count: 2, size: 0.8),
    ], _Colors.lfDayBird);
    _hillsAndCampTrees('lfDay', _Colors.lfDayHill, _Colors.lfDayTrees);

    final rand = _Rng(17);
    final smokePaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (var i = 0; i < 7; i++) {
      final duration = 13 + rand.next() * 5;
      final dx = 60 + rand.next() * 90;
      final p = _phase(t, duration, -(i / 7) * duration);
      final eased = Curves.easeOut.transform(p);
      final opacity = _keyframes(p, const [(0, 0), (0.15, 0.32), (1, 0)]);
      final scale = _lerp(0.6, 3.2, eased);
      smokePaint.color = _Colors.lfDaySmoke.withValues(alpha: opacity);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(600 + dx * eased, 380 - 330 * eased),
          width: 52 * scale,
          height: 40 * scale,
        ),
        smokePaint,
      );
    }

    final ember = _lerp(0.45, 0.8, _alternate(t, 4.5));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(600, 392), width: 92, height: 20),
      _fill(_Colors.lfDayEmber, ember),
    );
    for (final angle in const [-10.0, 10.0]) {
      canvas.save();
      canvas.translate(600, 388);
      canvas.rotate(angle * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-48, -6, 96, 12),
          const Radius.circular(6),
        ),
        _fill(_Colors.lfDayLog),
      );
      canvas.restore();
    }
  }

  void lagerfeuerNacht() {
    _sky(_Colors.lfNightTop, _Colors.lfNightBottom);
    _hillsAndCampTrees('lfNight', _Colors.lfNightHill, _Colors.lfNightTrees);

    void glow(double rx, double ry, double cy, double value) {
      final scale = _lerp(1, 1.05, value);
      final opacity = _lerp(0.55, 0.8, value);
      final rect = Rect.fromCenter(
        center: Offset(600, cy),
        width: rx * 2 * scale,
        height: ry * 2 * scale,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            rect.width / 2,
            [
              _Colors.lfNightGlow.withValues(alpha: 0.55 * opacity),
              _Colors.lfNightGlow.withValues(alpha: 0),
            ],
            null,
            TileMode.clamp,
            Matrix4.diagonal3Values(1, rect.height / rect.width, 1).storage,
          ),
      );
    }

    glow(420, 260, 420, _alternate(t, 5.3));
    glow(260, 160, 430, 1 - _alternate(t, 3.7));

    final rand = _Rng(7);
    for (var i = 0; i < 16; i++) {
      final x = 600 + (rand.next() - 0.5) * 260;
      final duration = 9 + rand.next() * 8;
      final radius = 1.6 + rand.next() * 2.2;
      final dx = (rand.next() - 0.5) * 120;
      final delay = -rand.next() * duration;
      final p = _phase(t, duration, delay);
      final opacity = _keyframes(p, const [(0, 0), (0.12, 0.8), (1, 0)]);
      canvas.drawCircle(
        Offset(x + dx * p, 400 - 380 * p),
        radius,
        _fill(_Colors.lfNightSpark, opacity),
      );
    }
  }

  // --------------------------------------------------------------- Himmel

  void himmelTag() {
    _sky(_Colors.hDayTop, _Colors.hDayBottom);
    void cloud(double duration, double delay, double y, double s, double o) {
      final x = _lerp(-300, _w + 300, _phase(t, duration, delay));
      final paint = _fill(_Colors.hDayCloud, o);
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 140, height: 44),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-28, -14), width: 68, height: 48),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(20, -20), width: 80, height: 56),
        paint,
      );
      canvas.restore();
    }

    cloud(110, 0, 90, 1.2, 0.85);
    cloud(80, -40, 170, 0.8, 0.7);
    cloud(140, -90, 60, 0.6, 0.6);
    _birds(const [
      _Flock(y: 110, dir: 1, duration: 38, delay: -5, count: 5),
      _Flock(y: 70, dir: -1, duration: 52, delay: -26, count: 3, size: 0.8),
      _Flock(y: 190, dir: 1, duration: 64, delay: -44, count: 2, size: 0.7),
    ], _Colors.hDayBird);
    _skyline('hDay', _Colors.hDayHill, _Colors.hDayTrees);
  }

  static const List<_Shooting> _shootingStars = [
    _Shooting(1000, 40, -320, 130, 7.5, -1),
    _Shooting(180, 30, 300, 120, 9.5, -5),
    _Shooting(660, 10, -110, 190, 11, -8.5),
    _Shooting(880, 120, -260, 70, 13, -3),
  ];

  void himmelNacht() {
    _sky(_Colors.hNightTop, _Colors.hNightBottom);
    final rand = _Rng(21);
    for (var i = 0; i < 140; i++) {
      final x = rand.next() * _w;
      final y = rand.next() * 300;
      final radius = 0.8 + math.pow(rand.next(), 3) * 2.4;
      final duration = 3 + rand.next() * 4;
      final delay = -rand.next() * duration;
      final base = 0.55 + rand.next() * 0.4;
      final opacity = _lerp(base, base * 0.15, _alternate(t, duration, delay));
      canvas.drawCircle(
        Offset(x, y),
        radius.toDouble(),
        _fill(_Colors.hNightStar, opacity),
      );
    }

    const shootCurve = Cubic(0.3, 0.1, 0.6, 1);
    for (final star in _shootingStars) {
      final p = _phase(t, star.duration, star.delay);
      if (p < 0.8 || p > 0.92) {
        continue;
      }
      final opacity = _keyframes(p, const [(0.8, 0), (0.82, 0.9), (0.92, 0)]);
      final travel = shootCurve.transform((p - 0.8) / 0.12);
      final head = Offset(star.x + star.tx * travel, star.y + star.ty * travel);
      final direction =
          Offset(star.tx, star.ty) / Offset(star.tx, star.ty).distance;
      final tail = head - direction * 110;
      canvas.drawLine(
        head,
        tail,
        Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(head, tail, [
            _Colors.hNightStar.withValues(alpha: opacity),
            _Colors.hNightStar.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(head, 2.2, _fill(_Colors.hNightStar, opacity));
    }
    _skyline('hNight', _Colors.hNightHill, _Colors.hNightTrees);
  }

  // ----------------------------------------------------------------- Wald

  void _forest(
    String prefix, {
    required Color far,
    required Color mid,
    required Color near,
    required Color fog,
    required double fogOpacity,
    void Function()? between,
  }) {
    double sway(double duration, {bool reverse = false}) {
      final v = _alternate(t, duration);
      return _lerp(-18, 18, reverse ? 1 - v : v);
    }

    canvas.save();
    canvas.translate(sway(26), 0);
    _path(
      '$prefix.far',
      () => _pineRow(
        from: -60,
        to: 1260,
        y: 330,
        hMin: 120,
        hMax: 200,
        seed: 1,
        gap: 0.42,
      ),
      far,
    );
    canvas.restore();

    final fogX = _lerp(-220, 220, _alternate(t, 34));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-250 + fogX, 250, 1700, 70),
        const Radius.circular(35),
      ),
      _fill(fog, fogOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.save();
    canvas.translate(sway(19, reverse: true), 0);
    _path(
      '$prefix.mid',
      () => _pineRow(
        from: -60,
        to: 1260,
        y: 380,
        hMin: 160,
        hMax: 260,
        seed: 2,
        gap: 0.5,
      ),
      mid,
    );
    canvas.restore();

    between?.call();

    canvas.save();
    canvas.translate(sway(14), 0);
    _path(
      '$prefix.nearLeft',
      () => _pineRow(from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3),
      near,
    );
    _path(
      '$prefix.nearRight',
      () =>
          _pineRow(from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4),
      near,
    );
    canvas.restore();
    canvas.drawRect(const Rect.fromLTWH(0, 390, _w, 10), _fill(near));
  }

  void waldTag() {
    _sky(_Colors.wDayTop, _Colors.wDayBottom);
    const rays = [(380.0, 160.0), (560.0, 220.0), (760.0, 150.0)];
    for (var i = 0; i < rays.length; i++) {
      final (x, width) = rays[i];
      final opacity = _lerp(0.06, 0.24, _alternate(t, 10, -i * 3.3));
      final path = Path()
        ..moveTo(x, -10)
        ..lineTo(x + 40, -10)
        ..lineTo(x + width, _h)
        ..lineTo(x + width - 160, _h)
        ..close();
      canvas.drawPath(path, _fill(_Colors.wDayRay, opacity));
    }
    _forest(
      'wDay',
      far: _Colors.wDayFar,
      mid: _Colors.wDayMid,
      near: _Colors.wDayNear,
      fog: _Colors.wDayFog,
      fogOpacity: 0.6,
      between: () {
        _dragonfly(y: 250, dir: 1, duration: 34, delay: -6);
        _dragonfly(y: 210, dir: -1, duration: 42, delay: -22);
        _dragonfly(y: 290, dir: 1, duration: 50, delay: -38);
      },
    );
  }

  void waldNacht() {
    _sky(_Colors.wNightTop, _Colors.wNightBottom);
    _forest(
      'wNight',
      far: _Colors.wNightFar,
      mid: _Colors.wNightMid,
      near: _Colors.wNightNear,
      fog: _Colors.wNightFog,
      fogOpacity: 0.28,
    );
    final rand = _Rng(33);
    for (var i = 0; i < 24; i++) {
      final x = rand.next() * _w;
      final y = 140 + rand.next() * 240;
      final duration = 9 + rand.next() * 6;
      final radius = 1.6 + rand.next() * 1.4;
      final dx = (rand.next() - 0.5) * 80;
      final dy = -15 - rand.next() * 40;
      final delay = -rand.next() * duration;
      final p = _phase(t, duration, delay);
      const ease = Curves.easeInOut;
      final opacity = _keyframes(p, const [
        (0, 0),
        (0.3, 0.7),
        (0.55, 0.35),
        (0.75, 0.7),
        (1, 0),
      ], ease);
      final move = _keyframes(p, const [(0, 0), (0.55, 0.6), (1, 1)], ease);
      final moveY = _keyframes(p, const [(0, 0), (0.55, 0.5), (1, 1)], ease);
      final center = Offset(x + dx * move, y + dy * moveY);
      canvas.drawCircle(
        center,
        radius * 3,
        _fill(_Colors.wNightBug, 0.14 * opacity),
      );
      canvas.drawCircle(center, radius, _fill(_Colors.wNightBug, opacity));
    }
  }

  // ------------------------------------------------------ Tagesfiguren

  void _birds(List<_Flock> flocks, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final flock in flocks) {
      final x0 = flock.dir > 0 ? -80.0 : _w + 80;
      final x1 = flock.dir > 0 ? _w + 80 : -80.0;
      final p = _phase(t, flock.duration, flock.delay);
      final x = _lerp(x0, x1, p);
      final y = _keyframes(p, [
        (0, flock.y),
        (0.5, flock.y - 14),
        (1, flock.y + 20),
      ]);
      final s = 7 * flock.size;
      paint.strokeWidth = 1.8 * flock.size;
      for (var i = 0; i < flock.count; i++) {
        final ox = -flock.dir * i * 26 * flock.size;
        final oy = (i.isEven ? 1 : -1) * (i / 2).ceil() * 12 * flock.size;
        final flap = _lerp(1, -0.35, _alternate(t, 1.1, -i * 0.27));
        canvas.save();
        canvas.translate(x + ox, y + oy - 0.2 * s);
        canvas.scale(1, flap);
        canvas.translate(0, 0.2 * s);
        canvas.drawPath(
          Path()
            ..moveTo(-s, 0)
            ..quadraticBezierTo(-s / 2, -s * 0.8, 0, 0)
            ..quadraticBezierTo(s / 2, -s * 0.8, s, 0),
          paint,
        );
        canvas.restore();
      }
    }
  }

  void _dragonfly({
    required double y,
    required int dir,
    required double duration,
    required double delay,
  }) {
    final x0 = dir > 0 ? -60.0 : _w + 60;
    final x1 = dir > 0 ? _w + 60 : -60.0;
    final p = _phase(t, duration, delay);
    const ease = Curves.easeInOut;
    final progress = _keyframes(p, const [
      (0, 0),
      (0.24, 0.32),
      (0.34, 0.32),
      (0.6, 0.64),
      (0.7, 0.64),
      (1, 1),
    ], ease);
    final dy = _keyframes(p, const [
      (0, 0),
      (0.24, -12),
      (0.34, -12),
      (0.6, 8),
      (0.7, 8),
      (1, -4),
    ], ease);
    final color = _Colors.wDayFly;
    canvas.save();
    canvas.translate(_lerp(x0, x1, progress), y + dy);
    // Kopf zeigt nach rechts; fuer Fluege nach links spiegeln.
    canvas.scale(dir > 0 ? 1 : -1, 1);
    canvas.drawLine(
      const Offset(-20, 0),
      const Offset(2, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(3.5, 0), 1.8, _fill(color));
    final wing = _lerp(1, 0.7, _alternate(t, 1.4));
    canvas.save();
    canvas.scale(1, wing);
    void drawWing(
      double cx,
      double cy,
      double rx,
      double ry,
      double deg,
      double o,
    ) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        _fill(color, o),
      );
      canvas.restore();
    }

    drawWing(-1, -7, 1.8, 7, -8, 0.4);
    drawWing(-1, 7, 1.8, 7, 8, 0.4);
    drawWing(-4.5, -6, 1.6, 6, -18, 0.32);
    drawWing(-4.5, 6, 1.6, 6, 18, 0.32);
    canvas.restore();
    canvas.restore();
  }
}

class _Flock {
  const _Flock({
    required this.y,
    required this.dir,
    required this.duration,
    required this.delay,
    required this.count,
    this.size = 1,
  });

  final double y;
  final int dir;
  final double duration;
  final double delay;
  final int count;
  final double size;
}

class _Shooting {
  const _Shooting(this.x, this.y, this.tx, this.ty, this.duration, this.delay);

  final double x;
  final double y;
  final double tx;
  final double ty;
  final double duration;
  final double delay;
}
