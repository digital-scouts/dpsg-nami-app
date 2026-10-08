import 'package:flutter/material.dart';

/// Dezente Hinweiszeile fuer Daten, die Hitobito mit den Rechten der
/// angemeldeten Person nicht liefert (z. B. Rollen bei `group_read`).
class LeserechteHinweis extends StatelessWidget {
  const LeserechteHinweis({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(4, 2, 4, 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 15, color: farbe),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: farbe, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
