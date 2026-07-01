import 'package:flutter/material.dart';

import '../../core/notifications/pull_notification.dart';

Future<void> showUrgentNotificationModal(
  BuildContext context,
  PullNotification notification,
) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(notification.title.de),
      content: Text(notification.body.de),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
