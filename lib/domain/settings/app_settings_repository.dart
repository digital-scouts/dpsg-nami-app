import 'package:flutter/material.dart';

import '../taetigkeit/stufe.dart';
import 'app_settings.dart';

abstract class AppSettingsRepository {
  Future<AppSettings> load();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<void> saveLanguageCode(String code);
  Future<void> saveAnalyticsEnabled(bool enabled);
  Future<void> saveBiometricLockEnabled(bool enabled) async {}
  Future<void> saveNotificationsEnabled(bool enabled);
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled);
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen);
}
