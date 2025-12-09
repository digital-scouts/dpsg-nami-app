import 'package:flutter/material.dart';

import 'app_settings.dart';

abstract class AppSettingsRepository {
  Future<AppSettings> load();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<void> saveLanguageCode(String code);
  Future<void> saveAnalyticsEnabled(bool enabled);
}
