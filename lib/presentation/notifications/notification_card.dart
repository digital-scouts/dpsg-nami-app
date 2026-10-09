import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/l10n/app_localizations.dart';

import '../../core/notifications/pull_notification.dart';

/// Meldungskarte: neutrale Fläche, links ein Streifen in der Farbe der
/// Priorität, darunter Titel, Text, Datum und die Aktionen.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onAcknowledge,
    this.onOpenLink,
    this.kopfzeile,
  });

  final PullNotification notification;
  final VoidCallback? onTap;

  /// Ohne Callback gibt es keine Bestätigen-Aktion (z. B. interne Meldungen).
  final VoidCallback? onAcknowledge;

  /// Ohne Callback gibt es keine Link-Aktion.
  final VoidCallback? onOpenLink;

  /// Optionale Zeile über der Priorität, z. B. „1 von 3“ im Banner.
  final Widget? kopfzeile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUrgent = notification.type == 'urgent';
    final isWarn = notification.type == 'warn';

    final streifen = isUrgent
        ? const Color(0xFFCC1F2F)
        : isWarn
        ? (isDark ? const Color(0xFF8A6A00) : const Color(0xFFFFB300))
        : theme.colorScheme.outlineVariant;
    final labelFarbe = isUrgent
        ? (isDark ? const Color(0xFFFF8F9A) : const Color(0xFFCC1F2F))
        : isWarn
        ? (isDark ? const Color(0xFFFFD666) : const Color(0xFF8A6A00))
        : theme.colorScheme.onSurfaceVariant;
    final label = t.t(
      isUrgent
          ? 'notif_prio_urgent'
          : isWarn
          ? 'notif_prio_warn'
          : 'notif_prio_info',
    );
    final datum = notification.updatedAt ?? notification.createdAt;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('notification-streifen'),
                width: 5,
                color: streifen,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kopfzeile != null) ...[
                        kopfzeile!,
                        const SizedBox(height: 6),
                      ],
                      Text(
                        label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: labelFarbe,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.title.resolve(locale),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body.resolve(locale),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (datum != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMd(
                            locale.toString(),
                          ).format(datum.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (onOpenLink != null || onAcknowledge != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (onOpenLink != null)
                              FilledButton.tonalIcon(
                                key: const Key('notification-link-button'),
                                onPressed: onOpenLink,
                                icon: const Icon(Icons.north_east, size: 16),
                                iconAlignment: IconAlignment.end,
                                label: Text(t.t('notif_more_info')),
                              ),
                            if (onAcknowledge != null)
                              FilledButton(
                                key: const Key('notification-ack-button'),
                                onPressed: onAcknowledge,
                                style: isUrgent
                                    ? FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFCC1F2F,
                                        ),
                                        foregroundColor: Colors.white,
                                      )
                                    : null,
                                child: Text(t.t('acknowledge')),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
