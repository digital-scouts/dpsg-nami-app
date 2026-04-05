import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  group('AppSettings', () {
    test('defaults include notifications and birthday stages', () {
      const s = AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      );
      expect(s.biometricLockEnabled, isFalse);
      expect(s.notificationsEnabled, isTrue);
      expect(s.memberListSearchResultHighlightEnabled, isFalse);
      expect(s.geburstagsbenachrichtigungStufen, {
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
        Stufe.leitung,
      });
    });
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
        biometricLockEnabled: true,
        memberListSearchResultHighlightEnabled: true,
      );
      expect(s2.themeMode, ThemeMode.dark);
      expect(s2.languageCode, 'en');
      expect(s2.analyticsEnabled, false);
      expect(s2.biometricLockEnabled, isTrue);
      expect(s2.memberListSearchResultHighlightEnabled, isTrue);
      // original unchanged
      expect(s.themeMode, ThemeMode.light);
      expect(s.languageCode, 'de');
      expect(s.analyticsEnabled, true);
      expect(s.biometricLockEnabled, isFalse);
      expect(s.memberListSearchResultHighlightEnabled, isFalse);
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
      // defaults for new fields persist
      expect(s2.biometricLockEnabled, isFalse);
      expect(s2.notificationsEnabled, isTrue);
      expect(s2.memberListSearchResultHighlightEnabled, isFalse);
      expect(s2.geburstagsbenachrichtigungStufen, {
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
        Stufe.leitung,
      });
    });
  });
}
