import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'meldet optionales Update wenn lokale Version kleiner als latest ist',
    () async {
      final service = AppUpdateService(
        platformOverride: 'android',
        currentVersionProvider: () async => '1.0.0+12',
        manifestProvider: () async => {
          'android': {
            'latest': '1.1.0',
            'min_supported': '1.0.0',
            'store_url': 'https://example.com/android',
          },
        },
      );

      final info = await service.checkForUpdate();

      expect(info, isNotNull);
      expect(info!.isRequired, isFalse);
      expect(info.currentVersion, '1.0.0');
      expect(info.latestVersion, '1.1.0');
    },
  );

  test(
    'meldet erforderliches Update wenn lokale Version kleiner als min_supported ist',
    () async {
      final service = AppUpdateService(
        platformOverride: 'ios',
        currentVersionProvider: () async => '0.9.0',
        manifestProvider: () async => {
          'ios': {
            'latest': '1.1.0',
            'min_supported': '1.0.0',
            'store_url': 'https://example.com/ios',
          },
        },
      );

      final info = await service.checkForUpdate();

      expect(info, isNotNull);
      expect(info!.isRequired, isTrue);
      expect(info.minSupportedVersion, '1.0.0');
    },
  );

  test('liefert keinen Hinweis wenn lokale Version aktuell ist', () async {
    final service = AppUpdateService(
      platformOverride: 'android',
      currentVersionProvider: () async => '1.0.0',
      manifestProvider: () async => {
        'android': {
          'latest': '1.0.0',
          'min_supported': '0.9.0',
          'store_url': 'https://example.com/android',
        },
      },
    );

    final info = await service.checkForUpdate();

    expect(info, isNull);
  });

  test('verwendet Cache innerhalb des Fetch-Intervalls', () async {
    SharedPreferences.setMockInitialValues({});
    var fetchCalls = 0;
    final service = AppUpdateService(
      platformOverride: 'android',
      manifestUrl: 'https://example.com/version.json',
      minFetchInterval: const Duration(hours: 12),
      fetchTimeout: const Duration(seconds: 1),
      nowProvider: () => DateTime(2026, 3, 26, 12),
      currentVersionProvider: () async => '1.0.0',
      manifestBodyFetcher: (url, timeout) async {
        fetchCalls++;
        return '{"android":{"latest":"1.0.1","min_supported":"1.0.0","store_url":"https://example.com/android"}}';
      },
    );

    await service.checkForUpdate();
    await service.checkForUpdate();

    expect(fetchCalls, 1);
  });
}
