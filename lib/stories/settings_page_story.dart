import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';
import 'package:nami/presentation/screens/settings_notification_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/screens/settings_stamm_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story settingsPageStory() => Story(
  name: 'Screens/SettingsPage',
  builder: (context) {
    final version = context.knobs.text(label: 'App Version', initial: 'v0.2.0');
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: SettingsPage(
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
      ),
    );
  },
);

Story appSettingsPageStory() => Story(
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ThemeMode geändert: $mode')));
        },
        languageCode: 'de',
        onLanguageChanged: (code) {},
      ),
    );
  },
);

Story settingsNotificationPageStory() => Story(
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
        geburstagsbenachrichtigungStufen: {Stufe.woelfling, Stufe.pfadfinder},
        onNotificationsChanged: (v) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Benachrichtigungen geändert: $v')),
          );
        },
        geburstagsbenachrichtigungStufenChanged: (stufen) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Geburtstagsstufen: ${stufen.map((s) => s.shortDisplayName).join(', ')}',
              ),
            ),
          );
        },
      ),
    );
  },
);

Story buildSettingsStammPageStory() => Story(
  name: 'Screens/Settings Stamm',
  builder: (context) {
    final repo = InMemoryAddressSettingsRepository();
    final grenzen = StufenDefaults.build();
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: SettingsStammPage(
        addressRepository: repo,
        initialAltersgrenzen: grenzen,
        onSaveAltersgrenzen: (g) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Altersgrenzen gespeichert')),
          );
        },
        onStufenwechselChanged: (d) {},
      ),
    );
  },
);
