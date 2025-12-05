import 'package:flutter/material.dart';

class MapSkeleton extends StatelessWidget {
  const MapSkeleton({super.key, this.height = 200});

  final double height;

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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(5, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isDark
            ? ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -1, 0, 0, 0, 300, // R invert
                  0, -1, 0, 0, 300, // G invert
                  0, 0, -1, 0, 300, // B invert
                  0, 0, 0, 1, 0, // A unverändert
                ]),
                child: img,
              )
            : img,
      ),
    );
  }
}
