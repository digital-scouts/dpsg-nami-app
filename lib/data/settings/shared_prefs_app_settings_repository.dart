import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';

class SharedPrefsAppSettingsRepository implements AppSettingsRepository {
  static const String _keyThemeMode = 'themeMode';
  static const String _keyLanguageCode = 'languageCode';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs();
    final themeIndex = prefs.getInt(_keyThemeMode);
    final lang = prefs.getString(_keyLanguageCode);
    final themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    final languageCode = lang ?? 'de';
    return AppSettings(themeMode: themeMode, languageCode: languageCode);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefs();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  @override
  Future<void> saveLanguageCode(String code) async {
    final prefs = await _prefs();
    await prefs.setString(_keyLanguageCode, code);
  }
}
