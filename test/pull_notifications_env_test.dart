import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notifications_env.dart';

void main() {
  test('liefert Defaultwerte fuer fehlende Notification-Env', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    expect(PullNotificationsEnv.url, isEmpty);
    expect(PullNotificationsEnv.minFetchInterval, const Duration(hours: 1));
  });

  test('liest URL und Intervall aus der Env', () {
    dotenv.loadFromString(
      envString:
          'PULL_NOTIFICATIONS_URL=https://example.com/feed.json\nPULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS=6\n',
    );

    expect(PullNotificationsEnv.url, 'https://example.com/feed.json');
    expect(PullNotificationsEnv.minFetchInterval, const Duration(hours: 6));
  });

  test('faellt bei ungueltigem Intervall auf den Default zurueck', () {
    dotenv.loadFromString(
      envString: 'PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS=-1\n',
    );

    expect(PullNotificationsEnv.minFetchInterval, const Duration(hours: 1));
  });
}
