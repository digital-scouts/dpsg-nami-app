import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/core/notifications/local_notifications_data_source.dart';
import 'package:nami/core/notifications/pull_notification.dart';

void main() {
  late Directory tempDir;
  late Box box;
  late LocalNotificationsDataSource dataSource;

  PullNotification buildNotification(String id) {
    return PullNotification(
      id: id,
      title: const LocalizedString(de: 'Titel', en: 'Title'),
      body: const LocalizedString(de: 'Text', en: 'Body'),
      type: 'info',
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notifications_local_');
    Hive.init(tempDir.path);
    box = await Hive.openBox('notifications_box');
    dataSource = LocalNotificationsDataSource(box);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('speichert und liest Notifications aus Hive', () async {
    final notifications = [buildNotification('1'), buildNotification('2')];

    await dataSource.saveNotifications(notifications);

    final stored = dataSource.getNotifications();
    expect(stored.map((item) => item.id), containsAll(<String>['1', '2']));
  });

  test('persistiert den letzten Fetch-Zeitpunkt', () async {
    final timestamp = DateTime(2026, 3, 26, 12, 30);

    await dataSource.setLastFetchAt(timestamp);

    expect(await dataSource.getLastFetchAt(), timestamp);
  });

  test('acknowledge und reset verwalten bestaetigte IDs', () async {
    await dataSource.acknowledge('a');
    await dataSource.acknowledge('b');

    expect(await dataSource.getAcknowledgedIds(), {'a', 'b'});

    await dataSource.resetAcknowledgedNotifications();

    expect(await dataSource.getAcknowledgedIds(), isEmpty);
  });
}
