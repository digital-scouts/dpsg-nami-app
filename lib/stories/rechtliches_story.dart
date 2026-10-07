import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/screens/settings_rechtliches_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

const _sprachen = [
  Option(label: 'Deutsch', value: Locale('de')),
  Option(label: 'Englisch', value: Locale('en')),
];

Widget _app(Locale locale, Widget home) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: locale,
  home: home,
);

Story rechtlichesPageStory() => Story(
  name: 'Einstellungen/Impressum & Datenschutz',
  builder: (context) {
    final locale = context.knobs.options<Locale>(
      label: 'Sprache',
      initial: const Locale('de'),
      options: _sprachen,
    );
    final mitId = context.knobs.boolean(
      label: 'Installations-ID bekannt',
      initial: true,
    );
    return _app(
      locale,
      SettingsRechtlichesPage(
        installationsId: mitId ? 'q3ZkAbCdEfGh9fA2' : null,
        onOpenUrl: (_) async {},
      ),
    );
  },
);

Story willkommenStepperStory() => Story(
  name: 'App/Willkommen/Stepper',
  builder: (context) {
    final locale = context.knobs.options<Locale>(
      label: 'Sprache',
      initial: const Locale('de'),
      options: _sprachen,
    );
    final biometrie = context.knobs.boolean(
      label: 'Biometrie verfügbar',
      initial: true,
    );
    final schritt = context.knobs.sliderInt(
      label: 'Startschritt',
      initial: 0,
      min: 0,
      max: 3,
    );
    final abgelehnt = context.knobs.boolean(
      label: 'Benachrichtigungen abgelehnt',
      initial: false,
    );
    return _app(
      locale,
      WillkommenStepper(
        // Key erzwingt neuen State, wenn ein Knopf umgeschaltet wird.
        key: ValueKey('$biometrie-$schritt-$abgelehnt'),
        startSchritt: schritt,
        optionen: WillkommenOptionen(
          biometrieVerfuegbar: biometrie,
          biometrieAktiv: false,
          benachrichtigungenErlaubt: abgelehnt ? false : null,
          analyseAktiv: false,
          keineMobilenDaten: false,
          themeMode: ThemeMode.system,
          onBiometrieAktivieren: () async => true,
          onBenachrichtigungenAktivieren: () async => !abgelehnt,
          onAnalyseAendern: (_) async {},
          onKeineMobilenDatenAendern: (_) async {},
          onThemeAendern: (_) async {},
          onRechtliches: () {},
          onSystemEinstellungen: () {},
        ),
      ),
    );
  },
);
