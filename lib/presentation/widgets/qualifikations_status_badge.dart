import 'package:flutter/material.dart';

import '../../domain/qualifikation/qualifikations_status.dart';

class QualifikationsStatusBadge extends StatelessWidget {
  const QualifikationsStatusBadge({super.key, required this.status});

  final QualifikationsStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      QualifikationsStatus.gueltig => ('Gültig', Colors.green),
      QualifikationsStatus.baldAblaufend => ('Bald ablaufend', Colors.orange),
      QualifikationsStatus.fehlt => ('Fehlt', colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
