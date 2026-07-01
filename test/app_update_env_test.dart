import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/app_update_env.dart';

void main() {
  test('liefert Defaultwerte bei fehlender Env', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    expect(AppUpdateEnv.url, isEmpty);
    expect(AppUpdateEnv.minFetchInterval, const Duration(hours: 12));
    expect(AppUpdateEnv.fetchTimeout, const Duration(seconds: 5));
  });

  test('liest App-Update-Werte aus der Env', () {
    dotenv.loadFromString(
      envString:
          'APP_UPDATE_URL=https://example.com/version.json\nAPP_UPDATE_MIN_FETCH_INTERVAL_HOURS=2\nAPP_UPDATE_FETCH_TIMEOUT_SECONDS=9\n',
    );

    expect(AppUpdateEnv.url, 'https://example.com/version.json');
    expect(AppUpdateEnv.minFetchInterval, const Duration(hours: 2));
    expect(AppUpdateEnv.fetchTimeout, const Duration(seconds: 9));
  });

  test('faellt bei ungueltigen Werten auf Defaults zurueck', () {
    dotenv.loadFromString(
      envString:
          'APP_UPDATE_MIN_FETCH_INTERVAL_HOURS=-3\nAPP_UPDATE_FETCH_TIMEOUT_SECONDS=0\n',
    );

    expect(AppUpdateEnv.minFetchInterval, const Duration(hours: 12));
    expect(AppUpdateEnv.fetchTimeout, const Duration(seconds: 5));
  });
}
