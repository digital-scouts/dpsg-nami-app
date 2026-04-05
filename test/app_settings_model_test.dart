import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/app_settings_model.dart';

class _FakeRepo implements AppSettingsRepository {
  ThemeMode? savedMode;
  String? savedLang;
  bool? savedAnalytics;
  bool? savedBiometricLock;
  bool? savedNotifications;
  bool? savedSearchResultHighlight;
  Set<Stufe>? savedBirthdayStages;

  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: true,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {
    savedAnalytics = enabled;
  }

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {
    savedBiometricLock = enabled;
  }

  @override
  Future<void> saveLanguageCode(String code) async {
    savedLang = code;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    savedMode = mode;
  }

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {
    savedSearchResultHighlight = enabled;
  }

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {
    savedBirthdayStages = stufen;
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {
    savedNotifications = enabled;
  }
}

void main() {
  test('AppSettingsModel setters update state and persist', () async {
    final repo = _FakeRepo();
    final initial = await repo.load();
    final model = AppSettingsModel(initial, repo);

    await model.setNotificationsEnabled(false);
    expect(model.notificationsEnabled, isFalse);
    expect(repo.savedNotifications, isFalse);

    await model.setMemberListSearchResultHighlightEnabled(true);
    expect(model.memberListSearchResultHighlightEnabled, isTrue);
    expect(repo.savedSearchResultHighlight, isTrue);

    final set = {Stufe.woelfling, Stufe.pfadfinder};
    await model.setGeburstagsbenachrichtigungStufen(set);
    expect(model.geburstagsbenachrichtigungStufen, set);
    expect(repo.savedBirthdayStages, set);

    await model.setThemeMode(ThemeMode.dark);
    expect(model.themeMode, ThemeMode.dark);
    expect(repo.savedMode, ThemeMode.dark);

    await model.setLanguageCode('en');
    expect(model.languageCode, 'en');
    expect(repo.savedLang, 'en');

    await model.setAnalyticsEnabled(false);
    expect(model.analyticsEnabled, isFalse);
    expect(repo.savedAnalytics, isFalse);

    await model.setBiometricLockEnabled(true);
    expect(model.biometricLockEnabled, isTrue);
    expect(repo.savedBiometricLock, isTrue);
  });
}
