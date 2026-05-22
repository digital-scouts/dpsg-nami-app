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
    final isDark = theme.brightness == Brightness.dark;
    final isUrgent = notification.type == 'urgent';
    final isWarn = notification.type == 'warn';
    final backgroundColor = isUrgent
        ? (isDark ? const Color(0xFF3A1418) : const Color(0xFFFDECEE))
        : isWarn
        ? (isDark ? const Color(0xFF2A2010) : const Color(0xFFFFF8E1))
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor = isUrgent
        ? const Color(0xFFCC1F2F)
        : isWarn
        ? (isDark ? const Color(0xFF8A6A00) : const Color(0xFFFFB300))
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final foregroundColor = isUrgent
        ? (isDark ? const Color(0xFFFFC9CF) : const Color(0xFF7A1020))
        : isWarn
        ? (isDark ? const Color(0xFFFFE7A3) : const Color(0xFF795B00))
        : theme.colorScheme.onSurface;
    final iconColor = isUrgent
        ? borderColor
        : isWarn
        ? borderColor
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
            border: Border.all(color: borderColor),
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
                                  ? Icons.error_outline
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
