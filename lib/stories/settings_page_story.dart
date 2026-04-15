import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';
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
        onStammSettings: () => AppSnackbar.show(
          context,
          message: 'Stammeseinstellungen',
          type: AppSnackbarType.info,
        ),
        onAppSettings: () => AppSnackbar.show(
          context,
          message: 'Appeinstellungen',
          type: AppSnackbarType.info,
        ),
        onNotificationSettings: () => AppSnackbar.show(
          context,
          message: 'Benachrichtigungseinstellungen',
          type: AppSnackbarType.info,
        ),
        onMapSettings: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsMapPage())),
        onDebugTools: () => AppSnackbar.show(
          context,
          message: 'Debug & Tools',
          type: AppSnackbarType.info,
        ),
        onProfile: () => AppSnackbar.show(
          context,
          message: 'Profil',
          type: AppSnackbarType.info,
        ),
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
        biometricLockEnabled: false,
        memberListSearchResultHighlightEnabled: true,
        themeMode: ThemeMode.system,
        onAnalyticsChanged: (v) {
          AppSnackbar.show(
            context,
            message: 'Analytics geändert: $v',
            type: AppSnackbarType.info,
          );
        },
        onBiometricLockChanged: (v) {
          AppSnackbar.show(
            context,
            message: 'App-Sperre geändert: $v',
            type: AppSnackbarType.info,
          );
        },
        onMemberListSearchResultHighlightChanged: (v) {
          AppSnackbar.show(
            context,
            message: 'Suchhighlight geändert: $v',
            type: AppSnackbarType.info,
          );
        },
        onThemeModeChanged: (mode) {
          AppSnackbar.show(
            context,
            message: 'ThemeMode geändert: $mode',
            type: AppSnackbarType.info,
          );
        },
        languageCode: 'de',
        onLanguageChanged: (code) {},
      ),
    );
  },
);

Story appSettingsPageEnglishStory() => Story(
  name: 'Screens/AppSettingsPage/EnglishAnalyticsOn',
  builder: (context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('en'),
      home: AppSettingsPage(
        analyticsEnabled: true,
        biometricLockEnabled: true,
        memberListSearchResultHighlightEnabled: true,
        themeMode: ThemeMode.dark,
        languageCode: 'en',
        onAnalyticsChanged: (_) {},
        onBiometricLockChanged: (_) {},
        onMemberListSearchResultHighlightChanged: (_) {},
        onThemeModeChanged: (_) {},
        onLanguageChanged: (_) {},
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
          AppSnackbar.show(
            context,
            message: 'Benachrichtigungen geändert: $v',
            type: AppSnackbarType.info,
          );
        },
        geburstagsbenachrichtigungStufenChanged: (stufen) {
          AppSnackbar.show(
            context,
            message:
                'Geburtstagsstufen: ${stufen.map((s) => s.shortDisplayName).join(', ')}',
            type: AppSnackbarType.info,
          );
        },
      ),
    );
  },
);

Story settingsNotificationPageDisabledStory() => Story(
  name: 'Screens/SettingsNotificationPage/Disabled',
  builder: (context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: const SettingsNotificationPage(
        notificationsEnabled: false,
        geburstagsbenachrichtigungStufen: {},
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
          AppSnackbar.show(
            context,
            message: 'Altersgrenzen gespeichert',
            type: AppSnackbarType.success,
          );
        },
        onStufenwechselChanged: (d) {},
      ),
    );
  },
);
