import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('copyWith updates fields', () {
      const s = AppSettings(themeMode: ThemeMode.light, languageCode: 'de');
      final s2 = s.copyWith(themeMode: ThemeMode.dark, languageCode: 'en');
      expect(s2.themeMode, ThemeMode.dark);
      expect(s2.languageCode, 'en');
      // original unchanged
      expect(s.themeMode, ThemeMode.light);
      expect(s.languageCode, 'de');
    });

    test('copyWith partial updates', () {
      const s = AppSettings(themeMode: ThemeMode.light, languageCode: 'de');
      final s2 = s.copyWith(languageCode: 'en');
      expect(s2.themeMode, ThemeMode.light);
      expect(s2.languageCode, 'en');
    });
  });
}
