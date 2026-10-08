import 'package:flutter/material.dart';

import '../appearance/support_access.dart';
import '../taetigkeit/stufe.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String languageCode;
  final bool analyticsEnabled;
  final bool biometricLockEnabled;
  final bool notificationsEnabled;
  final bool noMobileDataEnabled;
  final bool memberListSearchResultHighlightEnabled;
  final Set<Stufe> geburstagsbenachrichtigungStufen;

  /// Testschalter in Debug & Tools: simuliert einen Kauf, bis eine
  /// Store-Anbindung den Zugang liefert.
  final SupporterTestZugang supporterTestZugang;

  const AppSettings({
    required this.themeMode,
    required this.languageCode,
    required this.analyticsEnabled,
    this.biometricLockEnabled = false,
    this.notificationsEnabled = true,
    this.noMobileDataEnabled = false,
    this.memberListSearchResultHighlightEnabled = false,
    this.geburstagsbenachrichtigungStufen = const {
      Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
      Stufe.leitung,
    },
    this.supporterTestZugang = SupporterTestZugang.keiner,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    bool? analyticsEnabled,
    bool? biometricLockEnabled,
    bool? notificationsEnabled,
    bool? noMobileDataEnabled,
    bool? memberListSearchResultHighlightEnabled,
    Set<Stufe>? geburstagsbenachrichtigungStufen,
    SupporterTestZugang? supporterTestZugang,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    noMobileDataEnabled: noMobileDataEnabled ?? this.noMobileDataEnabled,
    memberListSearchResultHighlightEnabled:
        memberListSearchResultHighlightEnabled ??
        this.memberListSearchResultHighlightEnabled,
    geburstagsbenachrichtigungStufen:
        geburstagsbenachrichtigungStufen ??
        this.geburstagsbenachrichtigungStufen,
    supporterTestZugang: supporterTestZugang ?? this.supporterTestZugang,
  );
}
