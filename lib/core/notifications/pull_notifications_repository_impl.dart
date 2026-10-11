import '../../services/network_access_policy.dart';
import 'local_notifications_data_source.dart';
import 'pull_notification.dart';
import 'pull_notifications_filter.dart';
import 'pull_notifications_repository.dart';
import 'remote_notifications_data_source.dart';

/// Repository mit SWR-Logik (Cache zuerst, dann Refresh)
class PullNotificationsRepositoryImpl implements PullNotificationsRepository {
  final RemoteNotificationsDataSource remote;
  final LocalNotificationsDataSource local;
  final Duration cacheExpiration;
  final Duration minFetchInterval;

  /// Mindestabstand, solange „Mobile Daten einschränken“ an ist und kein
  /// WLAN besteht. Meldungen laufen dann weiter, nur seltener.
  final Duration minFetchIntervalMobil;
  final NetworkAccessPolicy? networkAccessPolicy;
  final DateTime Function() nowProvider;
  final String Function() platformProvider;

  PullNotificationsRepositoryImpl({
    required this.remote,
    required this.local,
    this.cacheExpiration = const Duration(days: 7),
    this.minFetchInterval = const Duration(hours: 1),
    this.minFetchIntervalMobil = const Duration(hours: 6),
    this.networkAccessPolicy,
    this.nowProvider = DateTime.now,
    this.platformProvider = aktuellePlattformFuerMeldungen,
  });

  @override
  Future<List<PullNotification>> fetchNotifications({
    bool forceRefresh = false,
  }) async {
    // 1. Cache zuerst
    final cached = local.getNotifications();
    final lastFetchAt = await local.getLastFetchAt();
    final now = nowProvider();
    final shouldSkipRemote =
        !forceRefresh &&
        lastFetchAt != null &&
        now.difference(lastFetchAt) < await _abrufIntervall();

    if (cached.isNotEmpty && !forceRefresh) {
      // Cache sofort liefern, Remote nur nach Ablauf des Intervalls prüfen.
      if (!shouldSkipRemote) {
        _refreshInBackground();
      }
      return _sichtbar(cached, now);
    }

    if (shouldSkipRemote) {
      return _sichtbar(cached, now);
    }

    // 2. Remote holen (und speichern)
    try {
      // Meldungen sind klein und tragen Warnungen: Sie laufen auch bei
      // eingeschraenkten mobilen Daten, nur offline nicht.
      await networkAccessPolicy?.ensureNetworkAllowed(
        trigger: 'pull_notifications_fetch',
        feature: 'Mitteilungen',
        allowMobileDataOverride: true,
      );
      final fresh = await remote.fetch();
      await local.saveNotifications(fresh);
      await local.setLastFetchAt(now);
      return _sichtbar(fresh, now);
    } on NetworkAccessBlockedException {
      return _sichtbar(cached, now);
    } catch (e) {
      // Auch ein Fehlschlag zaehlt fuer das Intervall, sonst wiederholt
      // jeder Aufruf die Fehlanfrage (A-50).
      await local.setLastFetchAt(now);
      // Bei Fehler: Fallback auf Cache
      if (cached.isNotEmpty) return _sichtbar(cached, now);
      rethrow;
    }
  }

  Future<Duration> _abrufIntervall() async {
    final policy = networkAccessPolicy;
    if (policy == null || !policy.isNoMobileDataEnabled) {
      return minFetchInterval;
    }
    final decision = await policy.evaluateAccess(
      trigger: 'pull_notifications_interval',
      feature: 'Mitteilungen',
    );
    if (decision.isBlockedByNoMobileData &&
        minFetchIntervalMobil > minFetchInterval) {
      return minFetchIntervalMobil;
    }
    return minFetchInterval;
  }

  /// Der Cache bleibt vollständig; erst die Ausgabe wird nach Plattform und
  /// Zeitfenster gefiltert.
  List<PullNotification> _sichtbar(List<PullNotification> list, DateTime now) =>
      filterAktiveMeldungen(list, now: now, platform: platformProvider());

  void _refreshInBackground() {
    (() async {
          await networkAccessPolicy?.ensureNetworkAllowed(
            trigger: 'pull_notifications_background_refresh',
            feature: 'Mitteilungen',
            allowMobileDataOverride: true,
          );
          return remote.fetch();
        })()
        .then((fresh) async {
          await local.saveNotifications(fresh);
          await local.setLastFetchAt(nowProvider());
        })
        .catchError((Object error) async {
          // Nur Hintergrund: Fehler nicht melden, aber das Intervall
          // beginnen, damit nicht jeder Aufruf erneut anfragt.
          if (error is! NetworkAccessBlockedException) {
            await local.setLastFetchAt(nowProvider());
          }
        });
  }

  @override
  Future<void> acknowledgeNotification(String id) => local.acknowledge(id);

  @override
  Future<Set<String>> getAcknowledgedIds() => local.getAcknowledgedIds();

  @override
  Future<DateTime?> getLastFetchAt() => local.getLastFetchAt();

  @override
  Future<void> resetAcknowledgedNotifications() {
    return local.resetAcknowledgedNotifications();
  }
}
