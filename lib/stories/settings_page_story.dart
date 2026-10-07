import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';
import 'package:nami/presentation/screens/settings_notification_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/screens/settings_stamm_page.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/stories/profile_page_story.dart';
import 'package:nami/stories/story_tab_shell.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story settingsPageStory() => Story(
  name: 'Einstellungen/Screens/Uebersicht',
  builder: (context) {
    final version = context.knobs.text(label: 'App Version', initial: 'v0.2.0');
    final demoZugang = context.knobs.options<DemoZugang?>(
      label: 'Demo-Modus',
      initial: null,
      options: const [
        Option(label: 'Aus', value: null),
        Option(label: 'Stammesvorstand', value: DemoZugang.stammesvorstand),
        Option(label: 'Leitung', value: DemoZugang.leitung),
        Option(label: 'Bezirksvorstand', value: DemoZugang.bezirksvorstand),
      ],
    );
    final background = storyHeaderBackgroundKnob(context.knobs);
    final textScale = storyTextScaleKnob(context.knobs);
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final angemeldet = context.knobs.boolean(
      label: 'Angemeldet',
      initial: true,
    );
    return SettingsPageStoryScene(
      textScale: textScale,
      background: background,
      dark: dark,
      angemeldet: angemeldet,
      appVersion: version,
      demoZugang: demoZugang,
    );
  },
);

/// Einstellungs-Tab wie in der App: Profil-Header im Tab-Rahmen, optional
/// mit Fake-Anmeldung.
class SettingsPageStoryScene extends StatelessWidget {
  const SettingsPageStoryScene({
    super.key,
    required this.background,
    this.dark = false,
    this.angemeldet = true,
    this.appVersion = 'v1.0.0',
    this.demoZugang,
    this.simulateTopInset = true,
    this.textScale = 1,
  });

  final AppearanceBackgroundId? background;
  final bool dark;
  final bool angemeldet;
  final String appVersion;

  /// Gesetzt, wenn die Szene die laufende Demo mit diesem Zugang zeigt.
  final DemoZugang? demoZugang;
  final bool simulateTopInset;
  final double textScale;

  static const AuthProfile _profile = AuthProfile(
    namiId: 34,
    email: 'julia@example.com',
    firstName: 'Julia',
    lastName: 'Keller',
    nickname: 'Polka',
    language: 'de',
    roles: <AuthProfileRole>[
      AuthProfileRole(
        groupId: 11,
        groupName: 'Stamm Musterdorf',
        roleName: 'Stammesvorstand',
        roleClass: 'Group::Stamm::Stammesvorstand',
        permissions: <String>['layer_and_below_full', 'contact_data'],
      ),
      AuthProfileRole(
        groupId: 21,
        groupName: 'Trupp Kompass',
        roleName: 'Leitung',
        roleClass: 'Group::StammGruppeJungpfadfinder::Leitung',
        permissions: <String>['group_full'],
      ),
      AuthProfileRole(
        groupId: 30,
        groupName: 'Bezirk Rhein',
        roleName: 'Mitglied Arbeitskreis',
        roleClass: 'Group::Bezirk::Mitglied',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final page = StoryTabPage(
      key: ValueKey('$background-$dark-$angemeldet-$textScale'),
      tabIndex: 3,
      background: background,
      badge: angemeldet ? SupporterBadgeId.kompassPfadfinder : null,
      dark: dark,
      simulateTopInset: simulateTopInset,
      textScale: textScale,
      child: Builder(
        builder: (context) => SettingsPage(
          appVersion: appVersion,
          onStammSettings: () => _info(context, 'Stammeseinstellungen'),
          onAppSettings: () => _info(context, 'Appeinstellungen'),
          onAppearanceSettings: () => _info(context, 'Erscheinungsbild'),
          onNotificationSettings: () =>
              _info(context, 'Benachrichtigungseinstellungen'),
          onMapSettings: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsMapPage())),
          onMessages: () => _info(context, 'Meldungen'),
          onRechtliches: () => _info(context, 'Impressum & Datenschutz'),
          onDebugTools: demoZugang != null
              ? null
              : () => _info(context, 'Debug & Tools'),
          onExitDemo: demoZugang != null
              ? () => _info(context, 'Demo beenden')
              : null,
          demoZugang: demoZugang,
          onProfile: angemeldet ? () => _info(context, 'Profil') : null,
        ),
      ),
    );
    return StorySignedInScope(
      key: ValueKey(angemeldet),
      profile: angemeldet ? _profile : null,
      child: page,
    );
  }

  static void _info(BuildContext context, String message) {
    AppSnackbar.show(context, message: message, type: AppSnackbarType.info);
  }
}

Story appSettingsPageStory() => Story(
  name: 'Einstellungen/Screens/App',
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
        languageCode: 'de',
        onLanguageChanged: (code) {},
      ),
    );
  },
);

Story appSettingsPageEnglishStory() => Story(
  name: 'Einstellungen/Screens/App/EnglischAnalyticsAn',
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
        languageCode: 'en',
        onAnalyticsChanged: (_) {},
        onBiometricLockChanged: (_) {},
        onMemberListSearchResultHighlightChanged: (_) {},
        onLanguageChanged: (_) {},
      ),
    );
  },
);

Story settingsNotificationPageStory() => Story(
  name: 'Einstellungen/Screens/Benachrichtigungen',
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
  name: 'Einstellungen/Screens/Benachrichtigungen/Deaktiviert',
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
  name: 'Einstellungen/Screens/Stamm',
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
