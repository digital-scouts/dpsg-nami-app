import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';

class UrgentNotificationModel extends ChangeNotifier {
  PullNotification? _notification;
  Future<void> Function(String id)? _onAcknowledge;

  PullNotification? get notification => _notification;

  void setNotification(PullNotification? value) {
    final previousId = _notification?.id;
    final nextId = value?.id;
    if (previousId == nextId) {
      return;
    }
    _notification = value;
    notifyListeners();
  }

  void setAcknowledgeHandler(Future<void> Function(String id)? handler) {
    _onAcknowledge = handler;
  }

  Future<void> acknowledgeCurrent() async {
    final current = _notification;
    final handler = _onAcknowledge;
    if (current == null || handler == null) {
      return;
    }
    await handler(current.id);
  }
}
