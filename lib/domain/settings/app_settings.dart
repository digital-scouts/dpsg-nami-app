import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String languageCode;
  final bool analyticsEnabled;

  const AppSettings({
    required this.themeMode,
    required this.languageCode,
    required this.analyticsEnabled,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    bool? analyticsEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
  );
}
