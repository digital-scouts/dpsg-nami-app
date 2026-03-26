import 'package:flutter/material.dart';

import '../../core/notifications/pull_notification.dart';
import 'notifications_list.dart';

class NotificationsStory extends StatelessWidget {
  const NotificationsStory({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      PullNotification(
        id: '1',
        title: const LocalizedString(de: 'Wartung', en: 'Maintenance'),
        body: const LocalizedString(
          de: 'Serverwartung am 18.12.',
          en: 'Maintenance on Dec 18',
        ),
        type: 'urgent',
      ),
      PullNotification(
        id: '2',
        title: const LocalizedString(de: 'Hinweis', en: 'Note'),
        body: const LocalizedString(
          de: 'App-Update verfügbar',
          en: 'App update available',
        ),
        type: 'info',
      ),
    ];
    return NotificationsList(
      notifications: notifications,
      acknowledged: const {},
      onTap: (n) {},
      onAcknowledge: (n) {},
    );
  }
}
