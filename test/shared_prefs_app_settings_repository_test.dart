import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/shared_prefs_app_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsAppSettingsRepository', () {
    test('loads defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsAppSettingsRepository();
      final settings = await repo.load();
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.languageCode, 'de');
    });

    test('persists and loads theme and language', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsAppSettingsRepository();
      await repo.saveThemeMode(ThemeMode.dark);
      await repo.saveLanguageCode('en');
      final settings = await repo.load();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.languageCode, 'en');
    });
  });
}
