import 'package:flutter/material.dart';

import '../../domain/qualifikation/qualifikations_status.dart';
import '../theme/status_farben.dart';

class QualifikationsStatusBadge extends StatelessWidget {
  const QualifikationsStatusBadge({super.key, required this.status});

  final QualifikationsStatus status;

  @override
  Widget build(BuildContext context) {
    final farben = StatusFarben.of(context);
    final (label, color) = switch (status) {
      QualifikationsStatus.gueltig => ('Gültig', farben.gut),
      QualifikationsStatus.baldAblaufend => ('Bald ablaufend', farben.warnung),
      QualifikationsStatus.abgelaufen => ('Abgelaufen', farben.kritisch),
      QualifikationsStatus.fehlt => ('Fehlt', farben.kritisch),
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
