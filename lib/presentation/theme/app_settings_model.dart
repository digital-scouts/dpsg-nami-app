import 'package:flutter/material.dart';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';

class AppSettingsModel extends ChangeNotifier {
  final AppSettingsRepository _repo;

  ThemeMode themeMode;
  String languageCode;
  bool analyticsEnabled;

  AppSettingsModel(AppSettings initial, this._repo)
    : themeMode = initial.themeMode,
      languageCode = initial.languageCode,
      analyticsEnabled = initial.analyticsEnabled;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _repo.saveThemeMode(mode);
  }

  Future<void> setLanguageCode(String code) async {
    languageCode = code;
    notifyListeners();
    await _repo.saveLanguageCode(code);
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    analyticsEnabled = enabled;
    notifyListeners();
    await _repo.saveAnalyticsEnabled(enabled);
  }
}
