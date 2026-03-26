import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/core/notifications/local_notifications_data_source.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_impl.dart';
import 'package:nami/core/notifications/remote_notifications_data_source.dart';
import 'package:nami/services/logger_service.dart';

class FakeRemote implements RemoteNotificationsDataSource {
  FakeRemote(this.result);

  final List<PullNotification> result;
  int fetchCalls = 0;

  @override
  LoggerService get logger => throw UnimplementedError();

  @override
  String get url => '';

  @override
  Future<List<PullNotification>> fetch() async {
    fetchCalls++;
    return result;
  }
}

class FakeLocal implements LocalNotificationsDataSource {
  FakeLocal({required this.cached});

  final List<PullNotification> cached;
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
    });
  });
}
