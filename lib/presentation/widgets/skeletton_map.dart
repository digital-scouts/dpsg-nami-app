import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';

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
    final t = AppLocalizations.of(context);
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
              child: Container(
                alignment: Alignment.center,
                color: theme.colorScheme.surface.withValues(alpha: 0.35),
                child: Text(
                  t.t('map_not_available'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
