import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';
import '../../domain/taetigkeit/stufe.dart';

class SharedPrefsAppSettingsRepository implements AppSettingsRepository {
  static const String _keyThemeMode = 'themeMode';
  static const String _keyLanguageCode = 'languageCode';
  static const String _keyAnalyticsEnabled = 'analyticsEnabled';
  static const String _keyBiometricLockEnabled = 'biometricLockEnabled';
  static const String _keyNotificationsEnabled = 'notificationsEnabled';
  static const String _keyMemberListSearchResultHighlightEnabled =
      'memberListSearchResultHighlightEnabled';
  static const String _keyGeburstagsbenachrichtigungStufen =
      'geburstagsbenachrichtigungStufen';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs();
    final themeIndex = prefs.getInt(_keyThemeMode);
    final lang = prefs.getString(_keyLanguageCode);
    final analytics = prefs.getBool(_keyAnalyticsEnabled);
    final biometricLock = prefs.getBool(_keyBiometricLockEnabled);
    final notifications = prefs.getBool(_keyNotificationsEnabled);
    final searchResultHighlight = prefs.getBool(
      _keyMemberListSearchResultHighlightEnabled,
    );
    final stufenList = prefs.getStringList(
      _keyGeburstagsbenachrichtigungStufen,
    );
    final themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    final languageCode = lang ?? 'de';
    final analyticsEnabled = analytics ?? true;
    final biometricLockEnabled = biometricLock ?? false;
    final notificationsEnabled = notifications ?? true;
    final memberListSearchResultHighlightEnabled =
        searchResultHighlight ?? false;
    final geburstagsbenachrichtigungStufen = stufenList != null
        ? stufenList.map((s) => _stufeFromString(s)).whereType<Stufe>().toSet()
        : const {
            Stufe.biber,
            Stufe.woelfling,
            Stufe.jungpfadfinder,
            Stufe.pfadfinder,
            Stufe.rover,
            Stufe.leitung,
          };
    return AppSettings(
      themeMode: themeMode,
      languageCode: languageCode,
      analyticsEnabled: analyticsEnabled,
      biometricLockEnabled: biometricLockEnabled,
      notificationsEnabled: notificationsEnabled,
      memberListSearchResultHighlightEnabled:
          memberListSearchResultHighlightEnabled,
      geburstagsbenachrichtigungStufen: geburstagsbenachrichtigungStufen,
    );
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

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyAnalyticsEnabled, enabled);
  }

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyBiometricLockEnabled, enabled);
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyMemberListSearchResultHighlightEnabled, enabled);
  }

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {
    final prefs = await _prefs();
    final list = stufen.map((s) => s.name).toList();
    await prefs.setStringList(_keyGeburstagsbenachrichtigungStufen, list);
  }

  Stufe? _stufeFromString(String name) {
    try {
      return Stufe.values.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }
}
