import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/core/notifications/local_notifications_data_source.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_impl.dart';
import 'package:nami/core/notifications/remote_notifications_data_source.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';

import 'support/fake_connectivity.dart';

class FakeRemote implements RemoteNotificationsDataSource {
  FakeRemote(this.result, {this.fehler = false});

  final List<PullNotification> result;
  final bool fehler;
  int fetchCalls = 0;

  @override
  LoggerService get logger => throw UnimplementedError();

  @override
  String get url => '';

  @override
  Future<List<PullNotification>> fetch() async {
    fetchCalls++;
    if (fehler) {
      throw Exception('404');
    }
    return result;
  }
}

class FakeLocal implements LocalNotificationsDataSource {
  FakeLocal({required this.cached, this.lastFetchAt});

  final List<PullNotification> cached;
  DateTime? lastFetchAt;
  List<PullNotification>? savedNotifications;
  int getCalls = 0;

  @override
  Box get box => throw UnimplementedError();

  @override
  List<PullNotification> getNotifications() {
    getCalls++;
    return cached;
  }

  @override
  Future<void> saveNotifications(List<PullNotification> notifications) async {
    savedNotifications = notifications;
  }

  @override
  Future<DateTime?> getLastFetchAt() async => lastFetchAt;

  @override
  Future<void> setLastFetchAt(DateTime timestamp) async {
    lastFetchAt = timestamp;
  }

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<Set<String>> getAcknowledgedIds() async => <String>{};

  @override
  Future<void> resetAcknowledgedNotifications() async {}
}

void main() {
  group('PullNotificationsRepositoryImpl', () {
    late FakeRemote remote;
    late FakeLocal local;
    late PullNotificationsRepositoryImpl repo;

    test('fehlgeschlagener Abruf startet das Intervall (A-50)', () async {
      remote = FakeRemote(const [], fehler: true);
      local = FakeLocal(cached: const []);
      repo = PullNotificationsRepositoryImpl(remote: remote, local: local);

      await expectLater(repo.fetchNotifications(), throwsException);
      final zweiter = await repo.fetchNotifications();

      expect(remote.fetchCalls, 1);
      expect(zweiter, isEmpty);
      expect(local.lastFetchAt, isNotNull);
    });

    test('liefert Cache und refresht im Hintergrund', () async {
      final cached = [
        PullNotification(
          id: '1',
          title: const LocalizedString(de: 'A', en: 'A'),
          body: const LocalizedString(de: 'B', en: 'B'),
        ),
      ];
      remote = FakeRemote(cached);
      local = FakeLocal(cached: cached);
      repo = PullNotificationsRepositoryImpl(remote: remote, local: local);

      final result = await repo.fetchNotifications();

      expect(result, cached);
      expect(local.getCalls, 1);
      await Future<void>.delayed(Duration.zero);
      expect(remote.fetchCalls, 1);
      expect(local.savedNotifications, cached);
      expect(local.lastFetchAt, isNotNull);
    });

    test('ueberspringt Remote innerhalb des Fetch-Intervalls', () async {
      final cached = [
        PullNotification(
          id: '3',
          title: const LocalizedString(de: 'Aktuell', en: 'Current'),
          body: const LocalizedString(de: 'Cache', en: 'Cache'),
        ),
      ];
      remote = FakeRemote(cached);
      local = FakeLocal(
        cached: cached,
        lastFetchAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      repo = PullNotificationsRepositoryImpl(
        remote: remote,
        local: local,
        minFetchInterval: const Duration(hours: 1),
      );

      final result = await repo.fetchNotifications();

      expect(result, cached);
      await Future<void>.delayed(Duration.zero);
      expect(remote.fetchCalls, 0);
    });

    test('liefert Remote wenn kein Cache', () async {
      final remoteList = [
        PullNotification(
          id: '2',
          title: const LocalizedString(de: 'X', en: 'X'),
          body: const LocalizedString(de: 'Y', en: 'Y'),
        ),
      ];
      remote = FakeRemote(remoteList);
      local = FakeLocal(cached: const []);
      repo = PullNotificationsRepositoryImpl(remote: remote, local: local);

      final result = await repo.fetchNotifications();

      expect(result, remoteList);
      expect(remote.fetchCalls, 1);
      expect(local.savedNotifications, remoteList);
      expect(local.lastFetchAt, isNotNull);
    });
  });

  group('PullNotificationsRepositoryImpl Filter', () {
    final jetzt = DateTime.utc(2026, 6, 4, 12);
    PullNotification meldung(String id, {String? platform, DateTime? endsAt}) =>
        PullNotification(
          id: id,
          title: const LocalizedString(de: 'A', en: 'A'),
          body: const LocalizedString(de: 'B', en: 'B'),
          platform: platform,
          endsAt: endsAt,
        );

    test('filtert Cache-Ausgabe nach Plattform und Zeitfenster', () async {
      final cached = [
        meldung('alle'),
        meldung('android', platform: 'android'),
        meldung('abgelaufen', endsAt: jetzt),
      ];
      final local = FakeLocal(cached: cached, lastFetchAt: jetzt);
      final repo = PullNotificationsRepositoryImpl(
        remote: FakeRemote(cached),
        local: local,
        nowProvider: () => jetzt,
        platformProvider: () => 'ios',
      );

      final result = await repo.fetchNotifications();

      expect(result.map((n) => n.id), ['alle']);
    });

    test('speichert Remote ungefiltert und liefert gefiltert', () async {
      final fresh = [meldung('alle'), meldung('ios', platform: 'ios')];
      final local = FakeLocal(cached: const []);
      final repo = PullNotificationsRepositoryImpl(
        remote: FakeRemote(fresh),
        local: local,
        nowProvider: () => jetzt,
        platformProvider: () => 'android',
      );

      final result = await repo.fetchNotifications();

      expect(result.map((n) => n.id), ['alle']);
      expect(local.savedNotifications, fresh);
      expect(local.lastFetchAt, jetzt);
    });
  });

  group(
    'PullNotificationsRepositoryImpl bei eingeschraenkten mobilen Daten',
    () {
      final cached = [
        PullNotification(
          id: 'm',
          title: const LocalizedString(de: 'A', en: 'A'),
          body: const LocalizedString(de: 'B', en: 'B'),
        ),
      ];

      PullNotificationsRepositoryImpl repoMit(
        FakeRemote remote,
        FakeLocal local,
        FakeConnectivity connectivity,
      ) {
        return PullNotificationsRepositoryImpl(
          remote: remote,
          local: local,
          minFetchInterval: const Duration(hours: 1),
          minFetchIntervalMobil: const Duration(hours: 6),
          networkAccessPolicy: NetworkAccessPolicy(
            connectivity: connectivity,
            noMobileDataEnabled: () => true,
          ),
        );
      }

      test('laedt ueber Mobilfunk, wenn kein Cache da ist', () async {
        final remote = FakeRemote(cached);
        final local = FakeLocal(cached: const []);

        final result = await repoMit(
          remote,
          local,
          FakeConnectivity.mobile(),
        ).fetchNotifications();

        expect(result, cached);
        expect(remote.fetchCalls, 1);
      });

      test('fragt ueber Mobilfunk erst nach dem laengeren Intervall', () async {
        final remote = FakeRemote(cached);
        final local = FakeLocal(
          cached: cached,
          lastFetchAt: DateTime.now().subtract(const Duration(hours: 2)),
        );

        await repoMit(
          remote,
          local,
          FakeConnectivity.mobile(),
        ).fetchNotifications();
        await Future<void>.delayed(Duration.zero);

        expect(remote.fetchCalls, 0);
      });

      test('fragt im WLAN nach dem normalen Intervall', () async {
        final remote = FakeRemote(cached);
        final local = FakeLocal(
          cached: cached,
          lastFetchAt: DateTime.now().subtract(const Duration(hours: 2)),
        );

        await repoMit(
          remote,
          local,
          FakeConnectivity.wifi(),
        ).fetchNotifications();
        await Future<void>.delayed(Duration.zero);

        expect(remote.fetchCalls, 1);
      });

      test(
        'fragt ueber Mobilfunk nach Ablauf des laengeren Intervalls',
        () async {
          final remote = FakeRemote(cached);
          final local = FakeLocal(
            cached: cached,
            lastFetchAt: DateTime.now().subtract(const Duration(hours: 7)),
          );

          await repoMit(
            remote,
            local,
            FakeConnectivity.mobile(),
          ).fetchNotifications();
          await Future<void>.delayed(Duration.zero);

          expect(remote.fetchCalls, 1);
        },
      );
    },
  );
}
