import 'package:flutter/material.dart';

import '../../core/notifications/pull_notification.dart';
import 'notification_card.dart';
import 'notifications_list.dart';

/// Meldungskarten in allen Prioritäten, mit Link und als Urgent-Banner mit
/// Zähler.
class NotificationsStory extends StatelessWidget {
  const NotificationsStory({super.key});

  static final _urgent = PullNotification(
    id: '1',
    title: const LocalizedString(
      de: 'Bitte Update installieren',
      en: 'Please install the update',
    ),
    body: const LocalizedString(
      de: 'Version 1.0.1 behebt einen Fehler beim Speichern von Mitgliedsänderungen.',
      en: 'Version 1.0.1 fixes an error when saving member changes.',
    ),
    type: 'urgent',
    createdAt: DateTime.utc(2026, 10, 9),
    externalLink: 'https://digital-scouts.github.io/dpsg-nami-app/',
  );

  @override
  Widget build(BuildContext context) {
    final notifications = [
      _urgent,
      PullNotification(
        id: '2',
        title: const LocalizedString(
          de: 'Hitobito: Wartung am Samstag',
          en: 'Hitobito: maintenance on Saturday',
        ),
        body: const LocalizedString(
          de: 'Am Samstag von 8 bis 10 Uhr ist die Anmeldung zeitweise nicht möglich.',
          en: 'On Saturday from 8 to 10 am, login is temporarily unavailable.',
        ),
        type: 'warn',
        createdAt: DateTime.utc(2026, 10, 8),
        externalLink: 'https://digital-scouts.github.io/dpsg-nami-app/',
      ),
      PullNotification(
        id: '3',
        title: const LocalizedString(
          de: 'Neue Stufenfarben im Handbuch',
          en: 'New section colours in the manual',
        ),
        body: const LocalizedString(
          de: 'Das Handbuch wurde um die Seite zu den Stufenfarben ergänzt.',
          en: 'The manual now has a page on section colours.',
        ),
        type: 'info',
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: NotificationCard(
                notification: _urgent,
                kopfzeile: const Text('1 von 3 · Alle ansehen'),
                onOpenLink: () {},
                onAcknowledge: () {},
              ),
            ),
            Expanded(
              child: NotificationsList(
                notifications: notifications,
                acknowledged: const {},
                onTap: (n) {},
                onAcknowledge: (n) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
