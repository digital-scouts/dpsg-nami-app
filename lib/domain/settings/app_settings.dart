import 'package:flutter/material.dart';

import '../taetigkeit/stufe.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String languageCode;
  final bool analyticsEnabled;
  final bool notificationsEnabled;
  final bool memberListSearchResultHighlightEnabled;
  final Set<Stufe> geburstagsbenachrichtigungStufen;

  const AppSettings({
    required this.themeMode,
    required this.languageCode,
    required this.analyticsEnabled,
    this.notificationsEnabled = true,
    this.memberListSearchResultHighlightEnabled = false,
    this.geburstagsbenachrichtigungStufen = const {
      Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
      Stufe.leitung,
    },
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    bool? analyticsEnabled,
    bool? notificationsEnabled,
    bool? memberListSearchResultHighlightEnabled,
    Set<Stufe>? geburstagsbenachrichtigungStufen,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    memberListSearchResultHighlightEnabled:
        memberListSearchResultHighlightEnabled ??
        this.memberListSearchResultHighlightEnabled,
    geburstagsbenachrichtigungStufen:
        geburstagsbenachrichtigungStufen ??
        this.geburstagsbenachrichtigungStufen,
  );
}
