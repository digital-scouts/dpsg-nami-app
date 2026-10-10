import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';

void main() {
  PullNotification buildExternal({required String id, DateTime? endsAt}) {
    return PullNotification(
      id: id,
      title: const LocalizedString(de: 'Titel', en: 'Title'),
      body: const LocalizedString(de: 'Text', en: 'Body'),
      type: 'urgent',
      endsAt: endsAt,
      platform: 'all',
    );
  }

  group('NotificationsHub.mapVisibleExternal', () {
    test('versteckt bestaetigte Meldungen ohne ends_at', () {
      final result = NotificationsHub.mapVisibleExternal(
        notifications: [buildExternal(id: 'n1')],
        acknowledged: const {'n1'},
      );

      expect(result, isEmpty);
    });

    test('versteckt bestaetigte Meldungen auch mit ends_at', () {
      final result = NotificationsHub.mapVisibleExternal(
        notifications: [buildExternal(id: 'n2', endsAt: DateTime.utc(2099))],
        acknowledged: const {'n2'},
      );

      expect(result, isEmpty);
    });

    test('zeigt unbestaetigte Meldungen als ackbar', () {
      final result = NotificationsHub.mapVisibleExternal(
        notifications: [buildExternal(id: 'n3')],
        acknowledged: const {},
      );

      expect(result.single.id, 'n3');
      expect(result.single.ackable, isTrue);
      expect(result.single.acknowledged, isFalse);
    });

    test('includeAcknowledged zeigt bestaetigte Meldungen', () {
      final result = NotificationsHub.mapVisibleExternal(
        notifications: [buildExternal(id: 'n5')],
        acknowledged: const {'n5'},
        includeAcknowledged: true,
      );

      expect(result.single.id, 'n5');
      expect(result.single.acknowledged, isTrue);
    });
  });
}
