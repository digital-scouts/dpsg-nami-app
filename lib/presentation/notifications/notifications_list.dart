import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';

import 'notification_card.dart';

class NotificationsList extends StatelessWidget {
  final List<PullNotification> notifications;
  final Set<String> acknowledged;
  final void Function(PullNotification) onTap;
  final void Function(PullNotification) onAcknowledge;

  const NotificationsList({
    super.key,
    required this.notifications,
    required this.acknowledged,
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
        .where((n) => !acknowledged.contains(n.id))
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
        return NotificationCard(
          notification: notification,
          onTap: () => onTap(notification),
          onClose: () => onAcknowledge(notification),
        );
      },
    );
  }
}
