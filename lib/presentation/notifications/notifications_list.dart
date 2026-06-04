import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';

import 'notification_card.dart';

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
    final now = DateTime.now();
    final currentPlatform = _currentPlatform();
    final visible = notifications
        .where(
          (n) =>
              _isVisibleForPlatform(n.platform, currentPlatform) &&
              !_isNotStarted(n, now) &&
              !_isExpired(n, now),
        )
        .where((n) {
          if (showAcknowledged) {
            return true;
          }

          final isAcknowledged = acknowledged.contains(n.id);
          if (n.endsAt == null && isAcknowledged) {
            return false;
          }
          return true;
        })
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
          onClose: isAcknowledged ? null : () => onAcknowledge(notification),
        );
      },
    );
  }

  String _currentPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'all';
    }
  }

  bool _isVisibleForPlatform(String platform, String currentPlatform) {
    final normalized = platform.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return true;
    }
    return normalized == currentPlatform;
  }

  bool _isNotStarted(PullNotification notification, DateTime now) {
    final startsAt = notification.startsAt;
    return startsAt != null && startsAt.isAfter(now);
  }

  bool _isExpired(PullNotification notification, DateTime now) {
    final endsAt = notification.endsAt;
    return endsAt != null && !endsAt.isAfter(now);
  }
}
