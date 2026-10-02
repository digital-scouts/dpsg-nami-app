import 'package:flutter/material.dart';

/// Platzhalter waehrend die Kartenvorschau laedt. Bewusst ohne Text: ob die
/// Karte verfuegbar ist, steht erst nach dem Laden fest.
class MapSkeleton extends StatelessWidget {
  const MapSkeleton({
    super.key,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showShadow = true,
  });

  final double height;
  final BorderRadiusGeometry borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final img = Image.asset(
      'assets/images/map_skeleton.png',
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );

    final theme = Theme.of(context);
    final shadowColor = theme.colorScheme.onSurface.withValues(alpha: 0.18);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(5, 5),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            if (isDark)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -1, 0, 0, 0, 300, // R
                  0, -1, 0, 0, 300, // G
                  0, 0, -1, 0, 300, // B
                  0, 0, 0, 1, 0, // A
                ]),
                child: img,
              )
            else
              img,
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
