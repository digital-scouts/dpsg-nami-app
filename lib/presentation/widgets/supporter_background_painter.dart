import 'dart:math' as math;
import 'dart:typed_data';
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
    this.maxSceneHeight = defaultMaxSceneHeight,
  });

  final AppearanceBackgroundId background;
  final bool dark;

  /// Laufzeit der Animation in Sekunden.
  final double seconds;

  static const double designWidth = 1200;
  static const double designHeight = 400;

  /// Ab dieser Hoehe (logische Pixel) waechst die Szene nicht weiter; der
  /// Platz darueber wird mit Himmel (und je nach Szene Sternen) gefuellt.
  static const double defaultMaxSceneHeight = 220;

  final double maxSceneHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(
      size.width / designWidth,
      math.min(size.height, maxSceneHeight) / designHeight,
    );
    // Hoehe oberhalb der Szene in Designeinheiten.
    final extraTop = math.max(0.0, size.height / scale - designHeight);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - designWidth * scale) / 2,
      size.height - designHeight * scale,
    );
    canvas.scale(scale);
    final scene = _Scene(canvas, seconds, extraTop);
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
      oldDelegate.dark != dark ||
      oldDelegate.maxSceneHeight != maxSceneHeight;
}

const double _w = SupporterBackgroundPainter.designWidth;
const double _h = SupporterBackgroundPainter.designHeight;

// ------------------------------------------------------------------ Farben

class _Colors {
  static const white = Color(0xFFFFFFFF);
  // Lagerfeuer, Tag: Sitzkreis mit ausgebranntem, qualmendem Feuer
  static const lfDayTop = Color(0xFFE6EDF0);
  static const lfDayBottom = Color(0xFFF3E6D6);
  static const lfDayHill = Color(0xFFD8C7AE);
  static const lfDayTrees = Color(0xFFB9B08F);
  static const lfDaySmoke = Color(0xFF8F877F);
  static const lfDayBird = Color(0xFF56606A);
  static const lfDayBench = Color(0xFF7A5A44);
  static const lfDayBenchTop = Color(0xFFA07A5C);
  static const lfDayStone = Color(0xFFA8977F);
  static const lfDayStoneLit = Color(0xFFC7B69C);
  static const lfDayAsh = Color(0xFF5A4A40);
  static const lfDayCharred = Color(0xFF4A3A30);
  static const lfDayCharredAsh = Color(0xFF8C8278);
  static const lfDayEmber = Color(0xFFE9713A);
  static const lfDayEmber2 = Color(0xFFF08A45);
  // Lagerfeuer, Nacht: Feuerstelle mit Sitzkreis
  static const lfNightTop = Color(0xFF1D1512);
  static const lfNightBottom = Color(0xFF3A241B);
  static const lfNightHill = Color(0xFF2C1C16);
  static const lfNightTrees = Color(0xFF24170F);
  static const lfNightGlow = Color(0xFFE07A3C);
  static const lfNightSpark = Color(0xFFFFB56B);
  static const lfNightLog = Color(0xFF3A2418);
  static const lfNightLogLit = Color(0xFF6B4128);
  static const lfNightStone = Color(0xFF3B2A22);
  static const lfNightStoneLit = Color(0xFF7A4A30);
  // Himmel, Tag: tiefe Sonne und Lager in der Weite
  static const hDayTop = Color(0xFFB3CDE6);
  static const hDayBottom = Color(0xFFF7E6CF);
  static const hDayHill = Color(0xFFBCCBC2);
  static const hDayTrees = Color(0xFF9FB3A6);
  static const hDayCloud = Color(0xFFFFFFFF);
  static const hDayBird = Color(0xFF4D5A66);
  static const hDaySun = Color(0xFFFFF1D0);
  static const hDaySunGlow = Color(0xFFFFF4DC);
  static const hDayCamp = Color(0xFF6F7C84);
  static const hDaySmoke = Color(0xFF9AA6AD);
  // Himmel, Nacht: Milchstrasse mit Lager
  static const hNightTop = Color(0xFF0B1428);
  static const hNightBottom = Color(0xFF1D2F50);
  static const hNightHill = Color(0xFF15223B);
  static const hNightTrees = Color(0xFF0F1A2E);
  static const hNightStar = Color(0xFFE6ECF7);
  static const hNightHaze = Color(0xFFB9C3EF);
  static const hNightCamp = Color(0xFF070B16);
  static const campLight = Color(0xFFFFB45C);
  // Wald, Tag: Waldsee mit Libellen
  static const wDayTop = Color(0xFFE3EBE2);
  static const wDayBottom = Color(0xFFCFDCCD);
  static const wDayFar = Color(0xFFB9CBB8);
  static const wDayNear = Color(0xFF85A086);
  static const wDayFly = Color(0xFF4E6660);
  static const wDayWater = Color(0xFFC9DCD6);
  // Wald, Nacht: Mondlicht am See
  static const wNightTop = Color(0xFF0D1612);
  static const wNightBottom = Color(0xFF16241D);
  static const wNightFar = Color(0xFF1B2C23);
  static const wNightNear = Color(0xFF101C16);
  static const wNightFog = Color(0xFF6D8A7A);
  static const wNightBug = Color(0xFFF4E79A);
  static const wNightWater = Color(0xFF0E1A1F);
  static const wNightReed = Color(0xFF0A120E);
  static const wNightReflection = Color(0xFFC9D6EA);
  static const wNightRipple = Color(0xFF9FB3CF);
  static const wNightMoon = Color(0xFFE9EEF5);
  static const wNightMoonGlow = Color(0xFFDFE8F2);
  static const wNightBeam = Color(0xFFC9D9F0);
}

class _FireColors {
  const _FireColors({
    required this.glow,
    required this.log,
    required this.logLit,
    required this.outer,
    required this.mid,
    required this.inner,
  });

  final Color glow;
  final Color log;
  final Color logLit;
  final Color outer;
  final Color mid;
  final Color inner;

  static const night = _FireColors(
    glow: Color(0xFFE07A3C),
    log: Color(0xFF3A2418),
    logLit: Color(0xFF6B4128),
    outer: Color(0xFFD9542A),
    mid: Color(0xFFF5A03D),
    inner: Color(0xFFFFD98A),
  );
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

/// Lineare Phase 0..1..0 fuer CSS `alternate` mit mehreren Keyframes.
double _alternatePhase(double t, double duration, [double delay = 0]) {
  final p = _fract((t - delay) / (duration * 2)) * 2;
  return p <= 1 ? p : 2 - p;
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
  _Scene(this.canvas, this.t, this.extraTop);

  final Canvas canvas;
  final double t;

  /// Sichtbarer Bereich oberhalb der Szene (y von -extraTop bis 0).
  final double extraTop;

  Paint _fill(Color color, [double opacity = 1]) => Paint()
    ..color = color.withValues(alpha: color.a * opacity)
    ..isAntiAlias = true;

  void _sky(Color top, Color bottom) {
    if (extraTop > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, -extraTop - 1, _w, extraTop + 1),
        _fill(top),
      );
    }
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

  // ----------------------------------------------------------- Bausteine

  static const Curve _ease = Curves.easeInOut;

  double _sway(double duration, {bool reverse = false}) {
    final v = _alternate(t, duration);
    return _lerp(-18, 18, reverse ? 1 - v : v);
  }

  void _radialEllipse(
    Offset center,
    double rx,
    double ry,
    List<Color> colors, [
    List<double>? stops,
  ]) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, ry / rx);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()..shader = ui.Gradient.radial(Offset.zero, rx, colors, stops),
    );
    canvas.restore();
  }

  /// Weicher Lichthof, atmet langsam (9 s).
  void _halo(Offset center, double r, Color color, double strength) {
    final v = _alternate(t, 9);
    final opacity = _lerp(0.7, 1, v);
    final radius = r * _lerp(1, 1.06, v);
    _radialEllipse(
      center,
      radius,
      radius,
      [
        color.withValues(alpha: strength * opacity),
        color.withValues(alpha: strength * 0.4 * opacity),
        color.withValues(alpha: 0),
      ],
      const [0, 0.4, 1],
    );
  }

  void _cloud(double duration, double delay, double y, double s, double o) {
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

  void _kohte(
    double cx,
    double by,
    double h, {
    required Color cloth,
    bool lit = false,
  }) {
    final w = h * 0.98;
    final ay = by - h;
    final pole = Paint()
      ..color = cloth
      ..strokeWidth = h * 0.024
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - h * 0.1, ay - h * 0.17),
      Offset(cx + h * 0.05, ay + h * 0.09),
      pole,
    );
    canvas.drawLine(
      Offset(cx + h * 0.1, ay - h * 0.17),
      Offset(cx - h * 0.05, ay + h * 0.09),
      pole,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - w / 2, by)
        ..quadraticBezierTo(cx - w * 0.2, by - h * 0.52, cx, ay)
        ..quadraticBezierTo(cx + w * 0.2, by - h * 0.52, cx + w / 2, by)
        ..close(),
      _fill(cloth),
    );
    final dw = h * 0.15;
    final dh = h * 0.44;
    if (!lit) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - dw, by)
          ..lineTo(cx, by - dh)
          ..lineTo(cx + dw, by)
          ..close(),
        _fill(Color.lerp(cloth, _Colors.white, 0.1)!),
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - dw, by)
        ..quadraticBezierTo(cx - dw * 0.35, by - dh * 0.55, cx, by - dh)
        ..quadraticBezierTo(cx + dw * 0.35, by - dh * 0.55, cx + dw, by)
        ..close(),
      _fill(_Colors.campLight),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - dw * 0.45, by)
        ..quadraticBezierTo(cx - dw * 0.1, by - dh * 0.4, cx, by - dh * 0.62)
        ..quadraticBezierTo(cx + dw * 0.1, by - dh * 0.4, cx + dw * 0.45, by)
        ..close(),
      _fill(Color.lerp(_Colors.campLight, _Colors.white, 0.45)!, 0.75),
    );
  }

  /// Kleines Lager auf fernem Huegel, Kohten dicht beisammen.
  void _farCamp(double cx, double y, Color cloth, {bool lit = false}) {
    const tents = [(-34.0, 0.0, 40.0), (0.0, -3.0, 46.0), (32.0, 1.0, 36.0)];
    for (var i = 0; i < tents.length; i++) {
      final (dx, dy, h) = tents[i];
      _kohte(cx + dx, y + dy, h, cloth: cloth, lit: lit && i == 1);
    }
  }

  Path _flamePath(double x, double y, double w, double h) => Path()
    ..moveTo(x - w, y)
    ..cubicTo(
      x - w,
      y - h * 0.45,
      x - w * 0.15,
      y - h * 0.6,
      x + w * 0.1,
      y - h,
    )
    ..cubicTo(x + w * 0.25, y - h * 0.62, x + w, y - h * 0.5, x + w, y)
    ..close();

  /// Animiertes Feuer: fuenf Flammenschichten, Scheite und Glut.
  void _fire(double x, double y, double s, _FireColors c) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + 6 * s),
        width: 80 * s,
        height: 14 * s,
      ),
      _fill(c.glow, 0.55),
    );
    void layer(
      double dx,
      double w,
      double h,
      Color color,
      double duration,
      double delay,
    ) {
      final p = _alternatePhase(t, duration, delay);
      final sx = _keyframes(p, const [
        (0, 1),
        (0.35, 0.94),
        (0.7, 1.04),
        (1, 0.98),
      ], _ease);
      final sy = _keyframes(p, const [
        (0, 1),
        (0.35, 1.08),
        (0.7, 0.94),
        (1, 1.04),
      ], _ease);
      final skew =
          _keyframes(p, const [(0, 0), (0.35, -4), (0.7, 3), (1, -1)], _ease) *
          math.pi /
          180;
      final ox = x + dx * s;
      canvas.save();
      canvas.translate(ox, y);
      // CSS scale(sx, sy) skewX(skew), Ursprung unten mittig.
      canvas.transform(
        Float64List.fromList([
          sx,
          0,
          0,
          0,
          sx * math.tan(skew),
          sy,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
      );
      canvas.translate(-ox, -y);
      canvas.drawPath(_flamePath(ox, y, w * s, h * s), _fill(color));
      canvas.restore();
    }

    layer(-16, 16, 44, c.outer, 1.7, -0.4);
    layer(15, 15, 50, c.outer, 1.9, -1.1);
    layer(0, 26, 74, c.outer, 2.1, 0);
    layer(1, 18, 54, c.mid, 1.5, -0.7);
    layer(0, 9, 32, c.inner, 1.2, -0.3);
    for (final deg in const [-14.0, 14.0]) {
      final pivot = Offset(x, y + 4 * s);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(deg * math.pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 46 * s, y - 2 * s, 92 * s, 12 * s),
          Radius.circular(6 * s),
        ),
        _fill(c.log),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 46 * s, y - 2 * s, 92 * s, 4 * s),
          Radius.circular(2 * s),
        ),
        _fill(c.logLit),
      );
      canvas.restore();
    }
  }

  /// Flackernder Feuerschein (zwei Ellipsen, gegenlaeufig).
  void _fireGlow(double x, double y, double rx, double ry, Color glow) {
    void one(double cx, double cy, double rx, double ry, double v) {
      final opacity = _lerp(0.55, 0.85, v);
      final scale = _lerp(1, 1.06, v);
      final originY = cy + 0.4 * ry;
      canvas.save();
      canvas.translate(cx, originY);
      canvas.scale(scale);
      canvas.translate(-cx, -originY);
      _radialEllipse(Offset(cx, cy), rx, ry, [
        glow.withValues(alpha: 0.55 * opacity),
        glow.withValues(alpha: 0),
      ]);
      canvas.restore();
    }

    one(x, y, rx, ry, _alternate(t, 5.3));
    one(x, y + 10, rx * 0.6, ry * 0.6, 1 - _alternate(t, 3.7));
  }

  void _sparks(
    double x,
    double y,
    int count,
    double spread,
    double rise,
    Color color,
  ) {
    final rand = _Rng(7);
    for (var i = 0; i < count; i++) {
      final duration = 7 + rand.next() * 7;
      final cx = x + (rand.next() - 0.5) * spread;
      final radius = 1.4 + rand.next() * 1.8;
      final dx = (rand.next() - 0.5) * 120;
      final delay = -rand.next() * duration;
      final p = _phase(t, duration, delay);
      final opacity = _keyframes(p, const [(0, 0), (0.1, 0.85), (1, 0)]);
      canvas.drawCircle(
        Offset(cx + dx * p, y - rise * p),
        radius,
        _fill(color, opacity),
      );
    }
  }

  void _stoneRing(double x, double y, Color dark, Color lit) {
    final rand = _Rng(12);
    for (var i = 0; i < 11; i++) {
      final a = i / 11 * math.pi * 2;
      final rx = 15 + rand.next() * 5;
      final ry = 8 + rand.next() * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + math.cos(a) * 92, y + math.sin(a) * 18),
          width: rx * 2,
          height: ry * 2,
        ),
        _fill(math.sin(a) > 0 ? lit : dark),
      );
    }
  }

  void _bench(double x, double y, double w, Color log, Color top) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 16),
        const Radius.circular(8),
      ),
      _fill(log),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 5),
        const Radius.circular(2.5),
      ),
      _fill(top, 0.8),
    );
  }

  void _smoke(
    double x,
    double y,
    int count,
    double rise,
    Color color,
    int seed,
    double size,
  ) {
    final rand = _Rng(seed);
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (var i = 0; i < count; i++) {
      final duration = 13 + rand.next() * 5;
      final dx = 50 + rand.next() * 80;
      final p = _phase(t, duration, -(i / count) * duration);
      final eased = Curves.easeOut.transform(p);
      final opacity = _keyframes(p, const [
        (0, 0),
        (0.15, 0.3),
        (1, 0),
      ], Curves.easeOut);
      final scale = _lerp(0.6, 3, eased);
      paint.color = color.withValues(alpha: opacity);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + dx * eased, y - rise * eased),
          width: 44 * size * scale,
          height: 34 * size * scale,
        ),
        paint,
      );
    }
  }

  void _twinkleStars(
    int count,
    int seed,
    Color color, {
    double top = 0,
    double yMax = 300,
    _Band? band,
  }) {
    final rand = _Rng(seed);
    for (var i = 0; i < count; i++) {
      var x = rand.next() * _w;
      var y = top + rand.next() * yMax;
      if (band != null) {
        // Sterne entlang einer Diagonale verdichten (Milchstrasse).
        final along = rand.next();
        final spread =
            (rand.next() + rand.next() + rand.next() - 1.5) * band.width;
        x = band.x0 + (band.x1 - band.x0) * along - spread * band.ny;
        y = band.y0 + (band.y1 - band.y0) * along + spread * band.nx;
      }
      final radius = 0.7 + math.pow(rand.next(), 3) * 2.2;
      final duration = 3 + rand.next() * 4;
      final delay = -rand.next() * duration;
      final base = 0.45 + rand.next() * 0.45;
      final opacity = _lerp(base, base * 0.15, _alternate(t, duration, delay));
      canvas.drawCircle(Offset(x, y), radius.toDouble(), _fill(color, opacity));
    }
  }

  static const List<_Shooting> _shootingStars = [
    _Shooting(1000, 40, -320, 130, 7.5, -1),
    _Shooting(180, 30, 300, 120, 9.5, -5),
    _Shooting(660, 10, -110, 190, 11, -8.5),
    _Shooting(880, 120, -260, 70, 13, -3),
  ];

  void _shootingStarsLayer(Color color) {
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
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(head, 2.2, _fill(color, opacity));
    }
  }

  /// Glitzerlinie auf dem Wasser: wird schmaler und blasser, dann wieder
  /// breiter (Mitte bleibt stehen).
  void _shine(
    double x,
    double y,
    double width,
    double height,
    Color color,
    double duration,
    double delay,
  ) {
    final v = _alternate(t, duration, delay);
    final opacity = _lerp(0.55, 0.15, v);
    final scaledWidth = width * _lerp(1, 0.6, v);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + width / 2, y + height / 2),
          width: scaledWidth,
          height: height,
        ),
        Radius.circular(height / 2),
      ),
      _fill(color, opacity),
    );
  }

  /// Glitzer und Schilf eines Sees; gleicher Zufallsstrom wie der Entwurf.
  void _lake({
    required double top,
    required Color reedColor,
    Color? shineColor,
    double? shineX,
    bool drawShine = true,
    required void Function() between,
  }) {
    final rand = _Rng(5);
    for (var i = 0; i < 10; i++) {
      final duration = 5 + rand.next() * 4;
      final x = shineX == null
          ? 200 + rand.next() * 800
          : shineX - 40 + (rand.next() - 0.5) * 60;
      final width = shineX == null
          ? 40 + rand.next() * 60
          : 50 + rand.next() * 40;
      final delay = -rand.next() * duration;
      if (drawShine && shineColor != null) {
        _shine(x, top + 8 + i * 5, width, 2.5, shineColor, duration, delay);
      }
    }
    between();
    final reed = Paint()
      ..color = reedColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 14; i++) {
      final x = i < 7 ? 190 + i * 12.0 : 900 + (i - 7) * 12.0;
      final h = 40 + rand.next() * 40;
      canvas.drawPath(
        Path()
          ..moveTo(x, top + 20)
          ..quadraticBezierTo(x + 4, top + 20 - h * 0.6, x + 10, top + 20 - h),
        reed,
      );
    }
  }

  /// Wasserkreise: gleichmaessig verteilt, alle `period / count` Sekunden
  /// einer an einer anderen Stelle, nie mehrere gleichzeitig.
  void _ripples(
    int count,
    int seed,
    double yMin,
    double yMax,
    Color color,
    double period,
  ) {
    final rand = _Rng(seed);
    for (var i = 0; i < count; i++) {
      final x = 240 + rand.next() * 720;
      final y = yMin + rand.next() * (yMax - yMin);
      final delay = -(i / count) * period;
      for (final (k, extra) in const [(1.0, 0.0), (0.6, 0.5)]) {
        final p = _phase(t, period, delay + extra);
        if (p > 0.22) {
          continue;
        }
        final scale = _keyframes(p, const [
          (0, 0.1),
          (0.22, 1),
        ], Curves.easeOut);
        final opacity = _keyframes(p, const [
          (0, 0),
          (0.03, 0.65),
          (0.22, 0),
        ], Curves.easeOut);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: 60 * k * scale,
            height: 14 * k * scale,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * scale
            ..color = color.withValues(alpha: opacity),
        );
      }
    }
  }

  void _moonReflection(double x, double top, Color color) {
    final rand = _Rng(44);
    final v = _alternate(t, 9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, top + 22),
        width: 180 * _lerp(1, 1.06, v),
        height: 32 * _lerp(1, 1.06, v),
      ),
      _fill(color, _lerp(0.7, 1, v))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    for (var i = 0; i < 16; i++) {
      final duration = 4 + rand.next() * 4;
      final width = 70 - i * 3 + rand.next() * 30;
      final lx = x - width / 2 + (rand.next() - 0.5) * 24;
      final delay = -rand.next() * duration;
      _shine(lx, top + 4 + i * 4, width, 2.4, color, duration, delay);
    }
    // Schwache Reflexe ueber die ganze Seebreite.
    for (var i = 0; i < 14; i++) {
      final duration = 6 + rand.next() * 5;
      final lx = rand.next() * _w;
      final ly = top + 6 + rand.next() * 50;
      final width = 16 + rand.next() * 30;
      final delay = -rand.next() * duration;
      _shine(lx, ly, width, 1.6, color, duration, delay);
    }
  }

  /// Zwei weiche Lichtkeile, die am Mond beginnen und nach unten auslaufen.
  void _moonBeams(Offset moon, double bottom) {
    const beams = [(-200.0, 90.0, 0.0), (10.0, 120.0, -5.0)];
    for (final (dx, width, delay) in beams) {
      final opacity = _lerp(0.35, 0.7, _alternate(t, 12, delay));
      final path = Path()
        ..moveTo(moon.dx - 6, moon.dy)
        ..lineTo(moon.dx + 6, moon.dy)
        ..lineTo(moon.dx + dx + width / 2, bottom)
        ..lineTo(moon.dx + dx - width / 2, bottom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..shader = ui.Gradient.linear(
            moon,
            Offset(moon.dx - 120, bottom),
            [
              _Colors.wNightBeam.withValues(alpha: 0.5 * opacity),
              _Colors.wNightBeam.withValues(alpha: 0.18 * opacity),
              _Colors.wNightBeam.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
          ),
      );
    }
  }

  void _fireflies(int count, int seed, double peak) {
    final rand = _Rng(seed);
    for (var i = 0; i < count; i++) {
      final x = rand.next() * _w;
      final y = 160 + rand.next() * 220;
      final duration = 9 + rand.next() * 6;
      final radius = 1.6 + rand.next() * 1.4;
      final dx = (rand.next() - 0.5) * 80;
      final dy = -15 - rand.next() * 40;
      final delay = -rand.next() * duration;
      final p = _phase(t, duration, delay);
      final opacity = _keyframes(p, [
        (0, 0),
        (0.3, peak),
        (0.55, peak / 2),
        (0.75, peak),
        (1, 0),
      ], _ease);
      final moveX = _keyframes(p, const [(0, 0), (0.55, 0.6), (1, 1)], _ease);
      final moveY = _keyframes(p, const [(0, 0), (0.55, 0.5), (1, 1)], _ease);
      final center = Offset(x + dx * moveX, y + dy * moveY);
      canvas.drawCircle(
        center,
        radius * 3,
        _fill(_Colors.wNightBug, 0.14 * opacity),
      );
      canvas.drawCircle(center, radius, _fill(_Colors.wNightBug, opacity));
    }
  }

  void _farPines(String prefix, Color color) {
    canvas.save();
    canvas.translate(_sway(26), 0);
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
      color,
    );
    canvas.restore();
  }

  void _nearPines(String prefix, Color color) {
    canvas.save();
    canvas.translate(_sway(14), 0);
    _path(
      '$prefix.nearLeft',
      () => _pineRow(from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3),
      color,
    );
    _path(
      '$prefix.nearRight',
      () =>
          _pineRow(from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4),
      color,
    );
    canvas.restore();
  }

  // ---------------------------------------------------------- Lagerfeuer

  /// Tag: Sitzkreis, das Feuer ist heruntergebrannt und qualmt.
  void lagerfeuerTag() {
    _sky(_Colors.lfDayTop, _Colors.lfDayBottom);
    _birds(const [
      _Flock(y: 90, dir: 1, duration: 46, delay: -8, count: 3),
    ], _Colors.lfDayBird);
    _hillsAndCampTrees('lfDay', _Colors.lfDayHill, _Colors.lfDayTrees);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(600, 372), width: 520, height: 72),
      _fill(Color.lerp(_Colors.lfDayHill, _Colors.white, 0.25)!),
    );
    _bench(360, 376, 150, _Colors.lfDayBench, _Colors.lfDayBenchTop);
    _bench(700, 380, 160, _Colors.lfDayBench, _Colors.lfDayBenchTop);
    _stoneRing(600, 368, _Colors.lfDayStone, _Colors.lfDayStoneLit);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(600, 370), width: 92, height: 18),
      _fill(_Colors.lfDayAsh),
    );
    const charred = [-12.0, 14.0, 0.0];
    for (var i = 0; i < charred.length; i++) {
      final pivot = Offset(600, 366.0 + i);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(charred[i] * math.pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(548, 360.0 + i * 2, 104, 13),
          const Radius.circular(6.5),
        ),
        _fill(_Colors.lfDayCharred),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(560, 360.0 + i * 2, 30, 4),
          const Radius.circular(2),
        ),
        _fill(_Colors.lfDayCharredAsh, 0.8),
      );
      canvas.restore();
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(596, 366), width: 36, height: 8),
      _fill(_Colors.lfDayEmber, _lerp(0.25, 0.6, _alternate(t, 6))),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(614, 369), width: 18, height: 5),
      _fill(_Colors.lfDayEmber2, _lerp(0.25, 0.6, _alternate(t, 6, -2.5))),
    );
    _smoke(600, 352, 10, 320, _Colors.lfDaySmoke, 19, 0.9);
  }

  /// Nacht: Feuerstelle mit Steinring und Sitzbalken.
  void lagerfeuerNacht() {
    _sky(_Colors.lfNightTop, _Colors.lfNightBottom);
    _hillsAndCampTrees('lfNight', _Colors.lfNightHill, _Colors.lfNightTrees);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(600, 372), width: 520, height: 76),
      _fill(_Colors.lfNightGlow, 0.12),
    );
    _fireGlow(600, 350, 420, 250, _Colors.lfNightGlow);
    _bench(360, 376, 150, _Colors.lfNightLog, _Colors.lfNightLogLit);
    _bench(700, 380, 160, _Colors.lfNightLog, _Colors.lfNightLogLit);
    _stoneRing(600, 368, _Colors.lfNightStone, _Colors.lfNightStoneLit);
    _sparks(600, 330, 20, 70, 340, _Colors.lfNightSpark);
    _fire(600, 366, 1.35, _FireColors.night);
  }

  // --------------------------------------------------------------- Himmel

  /// Tag: tiefe Sonne, Wolken, Vögel und ein Lager in der Weite.
  void himmelTag() {
    _sky(_Colors.hDayTop, _Colors.hDayBottom);
    const sun = Offset(900, 200);
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    canvas.rotate(_phase(t, 120) * math.pi * 2);
    final ray = Path()
      ..moveTo(-6, -70)
      ..lineTo(6, -70)
      ..lineTo(40, -260)
      ..lineTo(-40, -260)
      ..close();
    for (var i = 0; i < 8; i++) {
      canvas.drawPath(ray, _fill(_Colors.hDaySunGlow, 0.14));
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();
    _halo(sun, 150, _Colors.hDaySunGlow, 0.7);
    canvas.drawCircle(sun, 42, _fill(_Colors.hDaySun));
    _cloud(110, 0, 90, 1.1, 0.85);
    _cloud(80, -40, 150, 0.8, 0.7);
    if (extraTop > 60) {
      _cloud(120, -60, -extraTop * 0.5, 0.9, 0.6);
    }
    _birds(const [
      _Flock(y: 110, dir: -1, duration: 40, delay: -12, count: 5),
    ], _Colors.hDayBird);
    _path(
      'hDay.farRidge',
      () => _ridge(y: 262, amp: 14, seed: 30),
      Color.lerp(_Colors.hDayHill, _Colors.white, 0.35)!,
    );
    _farCamp(520, 262, _Colors.hDayCamp);
    _smoke(540, 244, 5, 150, _Colors.hDaySmoke, 31, 0.45);
    _skyline('hDay', _Colors.hDayHill, _Colors.hDayTrees);
  }

  /// Nacht: Milchstrasse, Sternschnuppen und dasselbe Lager, eine Kohte
  /// leuchtet.
  void himmelNacht() {
    _sky(_Colors.hNightTop, _Colors.hNightBottom);
    final haze = _lerp(0.1, 0.2, _alternate(t, 14));
    canvas.save();
    canvas.translate(600, 140);
    canvas.rotate(math.atan2(240, 1080));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 1240, height: 120),
      _fill(_Colors.hNightHaze, haze)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.restore();
    _twinkleStars(80, 21, _Colors.hNightStar);
    _twinkleStars(220, 51, _Colors.hNightStar, band: _Band.milkyWay);
    // Weitere Baender nach oben, solange die Verlaengerung reicht.
    for (var band = 1; (band - 1) * 300 < extraTop; band++) {
      _twinkleStars(80, 21 + band * 97, _Colors.hNightStar, top: -band * 300.0);
    }
    _shootingStarsLayer(_Colors.hNightStar);
    _path(
      'hNight.farRidge',
      () => _ridge(y: 262, amp: 14, seed: 30),
      Color.lerp(_Colors.hNightHill, _Colors.white, 0.06)!,
    );
    _halo(const Offset(520, 256), 60, _Colors.campLight, 0.35);
    _farCamp(520, 262, _Colors.hNightCamp, lit: true);
    _skyline('hNight', _Colors.hNightHill, _Colors.hNightTrees);
  }

  // ----------------------------------------------------------------- Wald

  /// Tag: Waldsee mit Libellen und einzelnen Wasserkreisen.
  void waldTag() {
    _sky(_Colors.wDayTop, _Colors.wDayBottom);
    _farPines('wDay', _Colors.wDayFar);
    canvas.drawRect(
      const Rect.fromLTWH(0, 330, _w, 70),
      _fill(_Colors.wDayWater),
    );
    _lake(
      top: 330,
      reedColor: _Colors.wDayNear,
      shineColor: _Colors.white,
      between: () => _ripples(5, 61, 338, 380, _Colors.white, 20),
    );
    _dragonfly(y: 300, dir: 1, duration: 30, delay: -4);
    _dragonfly(y: 270, dir: -1, duration: 38, delay: -20);
    _nearPines('wDay', _Colors.wDayNear);
  }

  /// Nacht: Mondlicht über dem Wald, einige Sterne und ein See mit
  /// Mondspiegelung.
  void waldNacht() {
    _sky(_Colors.wNightTop, _Colors.wNightBottom);
    _twinkleStars(28, 91, _Colors.wNightMoonGlow, yMax: 170);
    for (var band = 1; (band - 1) * 300 < extraTop; band++) {
      _twinkleStars(
        40,
        91 + band * 97,
        _Colors.wNightMoonGlow,
        top: -band * 300.0,
      );
    }
    const moon = Offset(820, 80);
    _halo(moon, 110, _Colors.wNightMoonGlow, 0.25);
    canvas.drawCircle(moon, 26, _fill(_Colors.wNightMoon));
    _moonBeams(moon, 330);
    _farPines('wNight', _Colors.wNightFar);
    final fogX = _lerp(-220, 220, _alternate(t, 34));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-250 + fogX, 280, 1700, 60),
        const Radius.circular(30),
      ),
      _fill(_Colors.wNightFog, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 330, _w, 70),
      _fill(_Colors.wNightWater),
    );
    _lake(
      top: 330,
      reedColor: _Colors.wNightReed,
      shineX: 820,
      drawShine: false,
      between: () {
        _moonReflection(820, 330, _Colors.wNightReflection);
        _ripples(3, 81, 340, 380, _Colors.wNightRipple, 21);
      },
    );
    _nearPines('wNight', _Colors.wNightNear);
    _fireflies(10, 71, 0.6);
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
      const s = 7.0;
      paint.strokeWidth = 1.8;
      for (var i = 0; i < flock.count; i++) {
        final ox = -flock.dir * i * 26.0;
        final oy = (i.isEven ? 1 : -1) * (i / 2).ceil() * 12.0;
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
  });

  final double y;
  final int dir;
  final double duration;
  final double delay;
  final int count;
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

/// Diagonales Sternenband (Milchstrasse) in Designeinheiten.
class _Band {
  const _Band(this.x0, this.y0, this.x1, this.y1, this.width, this.nx, this.ny);

  final double x0;
  final double y0;
  final double x1;
  final double y1;
  final double width;

  /// Einheitsvektor entlang des Bandes.
  final double nx;
  final double ny;

  // Richtung (1080, 240) normiert.
  static const milkyWay = _Band(60, 20, 1140, 260, 70, 0.97619, 0.21693);
}
