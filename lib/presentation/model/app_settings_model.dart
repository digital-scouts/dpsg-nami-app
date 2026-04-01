import 'package:flutter/material.dart';

import '../../domain/settings/app_settings.dart';
import '../../domain/settings/app_settings_repository.dart';
import '../../domain/taetigkeit/stufe.dart';

class AppSettingsModel extends ChangeNotifier {
  final AppSettingsRepository _repo;

  ThemeMode themeMode;
  String languageCode;
  bool analyticsEnabled;
  bool notificationsEnabled;
  bool memberListSearchResultHighlightEnabled;
  Set<Stufe> geburstagsbenachrichtigungStufen;

  AppSettingsModel(AppSettings initial, this._repo)
    : themeMode = initial.themeMode,
      languageCode = initial.languageCode,
      analyticsEnabled = initial.analyticsEnabled,
      notificationsEnabled = initial.notificationsEnabled,
      memberListSearchResultHighlightEnabled =
          initial.memberListSearchResultHighlightEnabled,
      geburstagsbenachrichtigungStufen =
          initial.geburstagsbenachrichtigungStufen;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _repo.saveThemeMode(mode);
  }

  Future<void> setLanguageCode(String code) async {
    if (languageCode == code) {
      return;
    }

    languageCode = code;
    notifyListeners();
    await _repo.saveLanguageCode(code);
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    analyticsEnabled = enabled;
    notifyListeners();
    await _repo.saveAnalyticsEnabled(enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    notifyListeners();
    await _repo.saveNotificationsEnabled(enabled);
  }

  Future<void> setMemberListSearchResultHighlightEnabled(bool enabled) async {
    memberListSearchResultHighlightEnabled = enabled;
    notifyListeners();
    await _repo.saveMemberListSearchResultHighlightEnabled(enabled);
  }

  Future<void> setGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {
    geburstagsbenachrichtigungStufen = stufen;
    notifyListeners();
    await _repo.saveGeburstagsbenachrichtigungStufen(stufen);
  }
}
