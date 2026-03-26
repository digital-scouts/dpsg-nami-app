import 'local_notifications_data_source.dart';
import 'pull_notification.dart';
import 'pull_notifications_repository.dart';
import 'remote_notifications_data_source.dart';

/// Repository mit SWR-Logik (Cache zuerst, dann Refresh)
class PullNotificationsRepositoryImpl implements PullNotificationsRepository {
  final RemoteNotificationsDataSource remote;
  final LocalNotificationsDataSource local;
  final Duration cacheExpiration;

  PullNotificationsRepositoryImpl({
    required this.remote,
    required this.local,
    this.cacheExpiration = const Duration(days: 7),
  });

  DateTime? _lastFetch;

  @override
  Future<List<PullNotification>> fetchNotifications({
    bool forceRefresh = false,
  }) async {
    // 1. Cache zuerst
    final cached = local.getNotifications();
    final now = DateTime.now();
    final isCacheValid =
        _lastFetch != null && now.difference(_lastFetch!) < cacheExpiration;
    if (cached.isNotEmpty && !forceRefresh) {
      // Cache sofort liefern, damit der App-Start nicht blockiert.
      if (!isCacheValid) {
        _refreshInBackground();
      }
      return cached;
    }
    // 2. Remote holen (und speichern)
    try {
      final fresh = await remote.fetch();
      await local.saveNotifications(fresh);
      _lastFetch = DateTime.now();
      return fresh;
    } catch (e) {
      // Bei Fehler: Fallback auf Cache
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  void _refreshInBackground() {
    remote
        .fetch()
        .then((fresh) async {
          await local.saveNotifications(fresh);
          _lastFetch = DateTime.now();
        })
        .catchError((_) {
          /* Fehler ignorieren, da nur Hintergrund */
        });
  }

  @override
  Future<void> acknowledgeNotification(String id) => local.acknowledge(id);

  @override
  Future<Set<String>> getAcknowledgedIds() => local.getAcknowledgedIds();

  @override
  Future<void> resetAcknowledgedNotifications() {
    return local.resetAcknowledgedNotifications();
  }
}
