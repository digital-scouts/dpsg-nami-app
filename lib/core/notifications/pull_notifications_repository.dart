import 'pull_notification.dart';

abstract class PullNotificationsRepository {
  /// Holt die aktuellen Mitteilungen (aus Remote oder Cache, je nach Strategie)
  Future<List<PullNotification>> fetchNotifications({
    bool forceRefresh = false,
  });

  /// Markiert eine Mitteilung als bestätigt/ausgeblendet (lokal)
  Future<void> acknowledgeNotification(String id);

  /// Setzt alle Bestätigungen/Ausblendungen zurück
  Future<void> resetAcknowledgedNotifications();

  /// Gibt alle bestätigten/ausgeblendeten IDs zurück
  Future<Set<String>> getAcknowledgedIds();
}
