import 'dart:math';

import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final int particleCount;
  final Duration duration;
  final Alignment startAlignment;
  final double speedMin;
  final double speedMax;
  final double spreadRadians;
  final double bottomSpawnHeight;

  const ConfettiOverlay({
    super.key,
    this.particleCount = 230,
    this.duration = const Duration(seconds: 2),
    this.startAlignment = Alignment.bottomCenter,
    this.speedMin = 200,
    this.speedMax = 1200,
    this.spreadRadians = pi / 1.2,
    this.bottomSpawnHeight = 30,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _Particle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_tick)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    // Base start from alignment, but spread along bottom edge for wider coverage.
    final base = widget.startAlignment.alongSize(size);
    final particleCount = widget.particleCount;
    final bottomSpawnHeight = widget.bottomSpawnHeight;
    for (int i = 0; i < particleCount; i++) {
      // Randomize spawn around bottom area: x across full width, y near bottom.
      final spawnX = _rand.nextDouble() * size.width;
      final spawnY = size.height - (_rand.nextDouble() * bottomSpawnHeight);
      final start = Offset((spawnX * 0.8) + (base.dx * 0.2), spawnY);

      // Velocity: launch upwards with a wide spread left/right
      final min = widget.speedMin;
      final max = widget.speedMax;
      final speed = min + _rand.nextDouble() * (max - min);
      final upward = -pi / 2; // straight up
      final spread =
          (_rand.nextDouble() - 0.5) *
          widget.spreadRadians; // wide horizontal spread
      final angle = upward + spread;
      final vx = cos(angle) * speed;
      final vy = sin(angle) * speed; // negative = upwards initially

      // Appearance
      final sizePx = 4 + _rand.nextDouble() * 10;
      final color =
          Colors.primaries[_rand.nextInt(Colors.primaries.length)].shade400;
      final rotation = _rand.nextDouble() * pi;
      final rotationSpeed = (_rand.nextDouble() * 2 - 1) * 3; // radians/s

      _particles.add(
        _Particle(
          position: start,
          velocity: Offset(vx, vy),
          size: sizePx,
          color: color,
          rotation: rotation,
          rotationSpeed: rotationSpeed,
        ),
      );
    }
  }

  void _tick() {
    // delta time based on controller value
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _initParticles(size);
        final nowProgress = _controller.value;
        final dt = 1 / 60.0; // approximate frame time
        const gravity = 500.0; // px/s^2
        for (final p in _particles) {
          // simple physics: gravity pulling down, slight drag
          final vy = p.velocity.dy + gravity * dt;
          final vx = p.velocity.dx * 0.99; // minor horizontal drag
          p.velocity = Offset(vx, vy);
          p.position = Offset(
            p.position.dx + p.velocity.dx * dt,
            p.position.dy + p.velocity.dy * dt,
          );
          p.rotation += p.rotationSpeed * dt;
        }

        return IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _ConfettiPainter(
              _particles,
              opacity: 1.0 - nowProgress.clamp(0.0, 1.0),
            ),
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double opacity;

  _ConfettiPainter(this.particles, {required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withAlpha((opacity * 255).toInt());
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 1.6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return true;
  }
}
