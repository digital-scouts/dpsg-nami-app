import 'package:flutter/material.dart';

import '../../domain/appearance/appearance_catalog.dart';
import 'supporter_background_painter.dart';

/// Animierter Hintergrund (Tag im hellen, Nacht im dunklen Modus). Bei
/// "Bewegung reduzieren" wird ein Standbild gezeigt.
class SupporterBackground extends StatefulWidget {
  const SupporterBackground({
    super.key,
    required this.background,
    this.child,
    this.stillFrameSeconds = 12,
  });

  final AppearanceBackgroundId background;
  final Widget? child;

  /// Zeitpunkt des Standbilds bei reduzierter Bewegung.
  final double stillFrameSeconds;

  @override
  State<SupporterBackground> createState() => _SupporterBackgroundState();
}

class _SupporterBackgroundState extends State<SupporterBackground>
    with SingleTickerProviderStateMixin {
  // Lange Periode, damit sich die unterschiedlich langen Einzelanimationen
  // nicht sichtbar gleichzeitig wiederholen.
  static const Duration _period = Duration(minutes: 30);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final seconds = _controller.isAnimating
              ? _controller.value * _period.inSeconds
              : widget.stillFrameSeconds;
          return CustomPaint(
            painter: SupporterBackgroundPainter(
              background: widget.background,
              dark: dark,
              seconds: seconds,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
