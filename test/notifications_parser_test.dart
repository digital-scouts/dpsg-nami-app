import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';

void main() {
  group('PullNotification', () {
    test('fromJson mit minimalem Beispiel', () {
      final json = {
        'id': 'test-1',
        'title': {'de': 'Hallo', 'en': 'Hello'},
        'body': {'de': 'Text', 'en': 'Text'},
        'type': 'info',
        'platform': 'all',
      };
      final n = PullNotification.fromJson(json);
      expect(n.id, 'test-1');
      expect(n.title.de, 'Hallo');
      expect(n.body.en, 'Text');
      expect(n.type, 'info');
      expect(n.platform, 'all');
      expect(n.createdAt, isNull);
    });

    test('fromJson mit Legacy-String', () {
      final json = {'id': 'test-2', 'title': 'Hallo', 'body': 'Text'};
      final n = PullNotification.fromJson(json);
      expect(n.title.de, 'Hallo');
      expect(n.body.en, 'Text');
    });
  });
}
