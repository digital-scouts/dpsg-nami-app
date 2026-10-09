import 'package:flutter/foundation.dart';
import 'package:nami/core/notifications/pull_notification.dart';

/// Offene Urgent-Meldungen für das Banner über den Tabs. Das Banner zeigt
/// immer die erste; nach dem Bestätigen rückt die nächste nach.
class UrgentNotificationModel extends ChangeNotifier {
  List<PullNotification> _notifications = const [];
  Future<void> Function(String id)? _onAcknowledge;

  PullNotification? get notification =>
      _notifications.isEmpty ? null : _notifications.first;

  /// Anzahl aller offenen Urgent-Meldungen, einschließlich der angezeigten.
  int get count => _notifications.length;

  void setNotifications(List<PullNotification> value) {
    if (listEquals(
      _notifications.map((n) => n.id).toList(),
      value.map((n) => n.id).toList(),
    )) {
      return;
    }
    _notifications = List.unmodifiable(value);
    notifyListeners();
  }

  void setNotification(PullNotification? value) =>
      setNotifications(value == null ? const [] : [value]);

  void setAcknowledgeHandler(Future<void> Function(String id)? handler) {
    _onAcknowledge = handler;
  }

  Future<void> acknowledgeCurrent() async {
    final current = notification;
    final handler = _onAcknowledge;
    if (current == null || handler == null) {
      return;
    }
    await handler(current.id);
  }
}
