import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story settingsPageStory() {
  return Story(
    name: 'Screens/SettingsPage',
    builder: (context) {
      final version = context.knobs.text(
        label: 'App Version',
        initial: 'v0.2.0',
      );
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: SettingsPage(
          userName: context.knobs.text(
            label: 'User Name',
            initial: 'Max Mustermann',
          ),
          userId: context.knobs.text(label: 'User ID', initial: '123456'),
          appVersion: version,
          onStammSettings: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Stammeseinstellungen'))),
          onNotifications: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Benachrichtigungen'))),
          onAppSettings: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Appeinstellungen'))),
          onDebugTools: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Debug & Tools'))),
          onProfile: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profil'))),
          onLogout: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Logout'))),
        ),
      );
    },
  );
}
