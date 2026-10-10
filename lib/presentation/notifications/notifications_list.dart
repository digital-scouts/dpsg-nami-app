import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';

import 'notification_card.dart';
import 'notification_links.dart';

class NotificationsList extends StatelessWidget {
  final List<PullNotification> notifications;
  final Set<String> acknowledged;
  final bool showAcknowledged;
  final void Function(PullNotification) onTap;
  final void Function(PullNotification) onAcknowledge;

  const NotificationsList({
    super.key,
    required this.notifications,
    required this.acknowledged,
    this.showAcknowledged = false,
    required this.onTap,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (notifications.isEmpty) {
      return Center(child: Text(t.t('notifications_empty')));
    }
    final visible = notifications
        .where((n) => showAcknowledged || !acknowledged.contains(n.id))
        .toList();
    if (visible.isEmpty) {
      return Center(child: Text(t.t('notifications_empty')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = visible[index];
        final isAcknowledged = acknowledged.contains(notification.id);
        return NotificationCard(
          notification: notification,
          onTap: () => onTap(notification),
          onAcknowledge: isAcknowledged
              ? null
              : () => onAcknowledge(notification),
          onOpenLink:
              hatMeldungsLink(
                context,
                externalLink: notification.externalLink,
                deepLink: notification.deepLink,
              )
              ? () => oeffneMeldungsLink(
                  context,
                  externalLink: notification.externalLink,
                  deepLink: notification.deepLink,
                )
              : null,
        );
      },
    );
  }
}
