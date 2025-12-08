import 'package:flutter/material.dart';
import 'package:nami/presentation/screens/app_settings_page.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

Story appSettingsPageStory() {
  return Story(
    name: 'Screens/AppSettingsPage',
    builder: (context) {
      return AppSettingsPage(
        notificationsEnabled: true,
        analyticsEnabled: false,
        themeMode: ThemeMode.system,
        onNotificationsChanged: (v) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Benachrichtigungen geändert: $v')),
          );
        },
        onAnalyticsChanged: (v) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Analytics geändert: $v')));
        },
        onThemeModeChanged: (mode) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ThemeMode geändert: $mode')));
        },
        languageCode: 'de',
        onLanguageChanged: (code) {},
      );
    },
  );
}
