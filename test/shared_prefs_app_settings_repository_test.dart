import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/shared_prefs_app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
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

    test('notificationsEnabled defaults and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsAppSettingsRepository();
      final s0 = await repo.load();
      expect(s0.notificationsEnabled, isTrue);
      await repo.saveNotificationsEnabled(false);
      final s1 = await repo.load();
      expect(s1.notificationsEnabled, isFalse);
    });

    test('noMobileDataEnabled defaults and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsAppSettingsRepository();
      final s0 = await repo.load();
      expect(s0.noMobileDataEnabled, isFalse);
      await repo.saveNoMobileDataEnabled(true);
      final s1 = await repo.load();
      expect(s1.noMobileDataEnabled, isTrue);
    });

    test(
      'memberListSearchResultHighlightEnabled defaults and persists',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SharedPrefsAppSettingsRepository();
        final s0 = await repo.load();
        expect(s0.memberListSearchResultHighlightEnabled, isFalse);
        await repo.saveMemberListSearchResultHighlightEnabled(true);
        final s1 = await repo.load();
        expect(s1.memberListSearchResultHighlightEnabled, isTrue);
      },
    );

    test('geburstagsbenachrichtigungStufen defaults and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsAppSettingsRepository();
      final s0 = await repo.load();
      expect(s0.geburstagsbenachrichtigungStufen, {
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
        Stufe.leitung,
      });
      final set = {Stufe.woelfling, Stufe.pfadfinder, Stufe.leitung};
      await repo.saveGeburstagsbenachrichtigungStufen(set);
      final s1 = await repo.load();
      expect(s1.geburstagsbenachrichtigungStufen, set);
    });
  });
}
