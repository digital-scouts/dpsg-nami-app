import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';

void main() {
  PullNotification buildExternal({
    required String id,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    return PullNotification(
      id: id,
      title: const LocalizedString(de: 'Titel', en: 'Title'),
      body: const LocalizedString(de: 'Text', en: 'Body'),
      type: 'urgent',
      startsAt: startsAt,
      endsAt: endsAt,
      platform: 'all',
    );
  }

  group('NotificationsHub.mapVisibleExternal', () {
    final now = DateTime.utc(2026, 6, 4, 12);

    test('versteckt acknowledged ohne expires_at', () {
      final notifications = [buildExternal(id: 'n1')];

      final result = NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: const {'n1'},
        now: now,
      );

      expect(result, isEmpty);
    });

    test('zeigt acknowledged mit zukuenftigem expires_at weiter an', () {
      final notifications = [
        buildExternal(id: 'n2', endsAt: now.add(const Duration(days: 1))),
      ];

      final result = NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: const {'n2'},
        now: now,
      );

      expect(result.length, 1);
      expect(result.first.id, 'n2');
      expect(result.first.acknowledged, isTrue);
    });

    test('versteckt abgelaufene Meldungen immer', () {
      final notifications = [
        buildExternal(
          id: 'n3',
          endsAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];

      final result = NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: const {'n3'},
        now: now,
      );

      expect(result, isEmpty);
    });

    test('versteckt Meldungen vor starts_at', () {
      final notifications = [
        buildExternal(id: 'n4', startsAt: now.add(const Duration(hours: 2))),
      ];

      final result = NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: const {},
        now: now,
      );

      expect(result, isEmpty);
    });

    test('includeAcknowledged zeigt acknowledged ohne expires_at', () {
      final notifications = [buildExternal(id: 'n5')];

      final result = NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: const {'n5'},
        includeAcknowledged: true,
        now: now,
      );

      expect(result.length, 1);
      expect(result.first.id, 'n5');
      expect(result.first.acknowledged, isTrue);
    });
  });
}
