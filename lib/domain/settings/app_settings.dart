import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String languageCode;

  const AppSettings({required this.themeMode, required this.languageCode});

  AppSettings copyWith({ThemeMode? themeMode, String? languageCode}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
      );
}
