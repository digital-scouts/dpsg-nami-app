import 'package:flutter/material.dart';

import '../../core/notifications/pull_notification.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onClose,
  });

  final PullNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final isUrgent = notification.type == 'urgent';
    final isWarn = notification.type == 'warn';
    final backgroundColor = theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = theme.colorScheme.onSurface;
    final iconColor = isUrgent
        ? theme.colorScheme.error
        : isWarn
        ? theme.colorScheme.tertiary
        : foregroundColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUrgent || isWarn) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 8),
                            child: Icon(
                              isUrgent
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                              size: 20,
                              color: iconColor,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            notification.title.resolve(locale),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: foregroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      icon: Icon(Icons.close, color: foregroundColor),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notification.body.resolve(locale),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
