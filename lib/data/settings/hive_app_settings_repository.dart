import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';

class HiveAppSettingsRepository implements AppSettingsRepository {
  static const String _boxName = 'settings_box';
  static const String _keyThemeMode = 'themeMode';
  static const String _keyLanguageCode = 'languageCode';

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.openBox(_boxName);
      } catch (_) {
        // If Hive not initialized here, caller should have initialized Hive.
        // We still try to open to ensure lazy init of the box.
      }
    }
    return Hive.box(_boxName);
  }

  @override
  Future<AppSettings> load() async {
    final box = await _box();
    final themeIndex = box.get(_keyThemeMode) as int?;
    final lang = box.get(_keyLanguageCode) as String?;
    final themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    final languageCode = lang ?? 'de';
    return AppSettings(themeMode: themeMode, languageCode: languageCode);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final box = await _box();
    await box.put(_keyThemeMode, mode.index);
  }

  @override
  Future<void> saveLanguageCode(String code) async {
    final box = await _box();
    await box.put(_keyLanguageCode, code);
  }
}
