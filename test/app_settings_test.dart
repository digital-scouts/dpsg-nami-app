import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('copyWith updates fields', () {
      const s = AppSettings(
        themeMode: ThemeMode.light,
        languageCode: 'de',
        analyticsEnabled: true,
      );
      final s2 = s.copyWith(
        themeMode: ThemeMode.dark,
        languageCode: 'en',
        analyticsEnabled: false,
      );
      expect(s2.themeMode, ThemeMode.dark);
      expect(s2.languageCode, 'en');
      expect(s2.analyticsEnabled, false);
      // original unchanged
      expect(s.themeMode, ThemeMode.light);
      expect(s.languageCode, 'de');
      expect(s.analyticsEnabled, true);
    });

    test('copyWith partial updates', () {
      const s = AppSettings(
        themeMode: ThemeMode.light,
        languageCode: 'de',
        analyticsEnabled: true,
      );
      final s2 = s.copyWith(languageCode: 'en');
      expect(s2.themeMode, ThemeMode.light);
      expect(s2.languageCode, 'en');
      expect(s2.analyticsEnabled, true);
    });
  });
}
