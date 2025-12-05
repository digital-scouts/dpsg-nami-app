import 'package:flutter/material.dart';

import '../../domain/notifications/message_of_the_day.dart';

class MessageOfTheDayCard extends StatelessWidget {
  final MessageOfTheDay motd;
  final double maxBodyHeight;

  const MessageOfTheDayCard({
    super.key,
    required this.motd,
    this.maxBodyHeight = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(2, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_active,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  motd.header.isNotEmpty ? motd.header : 'Hinweis',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBodyHeight),
            child: SingleChildScrollView(
              child: Text(motd.bodyMarkdown, style: theme.textTheme.bodySmall),
            ),
          ),
          if (motd.action != null) ...[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: motd.action!.color),
              onPressed: () {
                // TODO: Opem link in InApp browser
              },
              child: Text(motd.action!.label),
            ),
          ],
        ],
      ),
    );
  }
}
