import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';

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
    if (notifications.isEmpty) {
      return const Center(child: Text('Keine Mitteilungen'));
    }
    final visible = notifications
        .where((n) => !acknowledged.contains(n.id))
        .toList();
    if (visible.isEmpty) {
      return const Center(child: Text('Keine Mitteilungen'));
    }
    return ListView(
      children: visible.map((n) {
        return Card(
          color: n.type == 'urgent'
              ? Colors.red[100]
              : n.type == 'warn'
              ? Colors.yellow[100]
              : null,
          child: ListTile(
            title: Text(n.title.de),
            subtitle: Text(n.body.de),
            trailing: IconButton(
              icon: const Icon(Icons.done),
              onPressed: () => onAcknowledge(n),
            ),
            onTap: () => onTap(n),
          ),
        );
      }).toList(),
    );
  }
}
