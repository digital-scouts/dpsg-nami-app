import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';
import 'package:nami/presentation/screens/settings_notification_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story appSettingsPageStory() {
  return Story(
    name: 'Screens/AppSettingsPage',
    builder: (context) {
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: AppSettingsPage(
          analyticsEnabled: false,
          themeMode: ThemeMode.system,
          onAnalyticsChanged: (v) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Analytics geändert: $v')));
          },
          onThemeModeChanged: (mode) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ThemeMode geändert: $mode')),
            );
          },
          languageCode: 'de',
          onLanguageChanged: (code) {},
        ),
      );
    },
  );
}

Story settingsNotificationPageStory() {
  return Story(
    name: 'Screens/SettingsNotificationPage',
    builder: (context) {
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: SettingsNotificationPage(
          notificationsEnabled: true,
          onNotificationsChanged: (v) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Benachrichtigungen geändert: $v')),
            );
          },
        ),
      );
    },
  );
}
