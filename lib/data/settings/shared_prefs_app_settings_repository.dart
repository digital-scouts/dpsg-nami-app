import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/appearance/support_access.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';
import '../../domain/taetigkeit/stufe.dart';

class SharedPrefsAppSettingsRepository implements AppSettingsRepository {
  static const String _keyThemeMode = 'themeMode';
  static const String _keyLanguageCode = 'languageCode';
  static const String _keyAnalyticsEnabled = 'analyticsEnabled';
  static const String _keyBiometricLockEnabled = 'biometricLockEnabled';
  static const String _keyNotificationsEnabled = 'notificationsEnabled';
  static const String _keyNoMobileDataEnabled = 'noMobileDataEnabled';
  static const String _keyMemberListSearchResultHighlightEnabled =
      'memberListSearchResultHighlightEnabled';
  static const String _keyGeburstagsbenachrichtigungStufen =
      'geburstagsbenachrichtigungStufen';
  static const String _keySupporterTestZugang = 'supporterTestZugangAuswahl';

  /// Frueher ein bool-Schalter, der alles freischaltete.
  static const String _keySupporterTestZugangAlt = 'supporterTestZugang';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs();
    final themeIndex = prefs.getInt(_keyThemeMode);
    final lang = prefs.getString(_keyLanguageCode);
    final analytics = prefs.getBool(_keyAnalyticsEnabled);
    final biometricLock = prefs.getBool(_keyBiometricLockEnabled);
    final notifications = prefs.getBool(_keyNotificationsEnabled);
    final noMobileData = prefs.getBool(_keyNoMobileDataEnabled);
    final searchResultHighlight = prefs.getBool(
      _keyMemberListSearchResultHighlightEnabled,
    );
    final stufenList = prefs.getStringList(
      _keyGeburstagsbenachrichtigungStufen,
    );
    final supporterTestZugang = _supporterTestZugang(prefs);
    final themeMode = themeIndex != null
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    final languageCode = lang ?? 'de';
    // Nutzungsereignisse nur nach Einwilligung (Willkommensdialog oder Einstellungen).
    final analyticsEnabled = analytics ?? false;
    final biometricLockEnabled = biometricLock ?? false;
    final notificationsEnabled = notifications ?? true;
    final noMobileDataEnabled = noMobileData ?? false;
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
      noMobileDataEnabled: noMobileDataEnabled,
      memberListSearchResultHighlightEnabled:
          memberListSearchResultHighlightEnabled,
      geburstagsbenachrichtigungStufen: geburstagsbenachrichtigungStufen,
      supporterTestZugang: supporterTestZugang,
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
  Future<void> saveNoMobileDataEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyNoMobileDataEnabled, enabled);
  }

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyMemberListSearchResultHighlightEnabled, enabled);
  }

  @override
  Future<void> saveSupporterTestZugang(SupporterTestZugang zugang) async {
    final prefs = await _prefs();
    await prefs.setString(_keySupporterTestZugang, zugang.name);
    await prefs.remove(_keySupporterTestZugangAlt);
  }

  SupporterTestZugang _supporterTestZugang(SharedPreferences prefs) {
    final name = prefs.getString(_keySupporterTestZugang);
    for (final zugang in SupporterTestZugang.values) {
      if (zugang.name == name) {
        return zugang;
      }
    }
    return prefs.getBool(_keySupporterTestZugangAlt) == true
        ? SupporterTestZugang.foerderer
        : SupporterTestZugang.keiner;
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
