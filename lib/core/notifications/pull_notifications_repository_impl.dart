import '../../services/network_access_policy.dart';
import 'local_notifications_data_source.dart';
import 'pull_notification.dart';
import 'pull_notifications_repository.dart';
import 'remote_notifications_data_source.dart';

/// Repository mit SWR-Logik (Cache zuerst, dann Refresh)
class PullNotificationsRepositoryImpl implements PullNotificationsRepository {
  final RemoteNotificationsDataSource remote;
  final LocalNotificationsDataSource local;
  final Duration cacheExpiration;
  final Duration minFetchInterval;
  final NetworkAccessPolicy? networkAccessPolicy;

  PullNotificationsRepositoryImpl({
    required this.remote,
    required this.local,
    this.cacheExpiration = const Duration(days: 7),
    this.minFetchInterval = const Duration(hours: 1),
    this.networkAccessPolicy,
  });

  @override
  Future<List<PullNotification>> fetchNotifications({
    bool forceRefresh = false,
  }) async {
    // 1. Cache zuerst
    final cached = local.getNotifications();
    // TODO(pull_notifications): Notifications hier zentral nach `platform` sowie `starts_at`/`ends_at` filtern, bevor sie an die UI gehen.
    final lastFetchAt = await local.getLastFetchAt();
    final now = DateTime.now();
    final shouldSkipRemote =
        !forceRefresh &&
        lastFetchAt != null &&
        now.difference(lastFetchAt) < minFetchInterval;

    if (cached.isNotEmpty && !forceRefresh) {
      // Cache sofort liefern, Remote nur nach Ablauf des Intervalls prüfen.
      if (!shouldSkipRemote) {
        _refreshInBackground();
      }
      return cached;
    }

    if (shouldSkipRemote) {
      return cached;
    }

    // 2. Remote holen (und speichern)
    try {
      await networkAccessPolicy?.ensureNetworkAllowed(
        trigger: 'pull_notifications_fetch',
        feature: 'Mitteilungen',
      );
      final fresh = await remote.fetch();
      await local.saveNotifications(fresh);
      await local.setLastFetchAt(now);
      return fresh;
    } on NetworkAccessBlockedException {
      return cached;
    } catch (e) {
      // Bei Fehler: Fallback auf Cache
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  void _refreshInBackground() {
    (() async {
          await networkAccessPolicy?.ensureNetworkAllowed(
            trigger: 'pull_notifications_background_refresh',
            feature: 'Mitteilungen',
          );
          return remote.fetch();
        })()
        .then((fresh) async {
          await local.saveNotifications(fresh);
          await local.setLastFetchAt(DateTime.now());
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
