import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/abmeldung_hinweis_karte.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story abmeldungHinweisKarteStory() => Story(
  name: 'App/Login/Hinweis nach Abmeldung',
  builder: (context) {
    final locale = context.knobs.options<Locale>(
      label: 'Sprache',
      initial: const Locale('de'),
      options: const [
        Option(label: 'Deutsch', value: Locale('de')),
        Option(label: 'Englisch', value: Locale('en')),
      ],
    );
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final grund = context.knobs.options<String>(
      label: 'Grund',
      initial: 'rechte',
      options: const [
        Option(label: 'Rechte geändert', value: 'rechte'),
        Option(label: 'Anmeldung unterbrochen', value: 'unterbrochen'),
        Option(label: 'Daten abgelaufen', value: 'abgelaufen'),
        Option(
          label: 'Daten abgelaufen, Änderungen verloren',
          value: 'verloren',
        ),
      ],
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: locale,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) {
                  final t = AppLocalizations.of(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      switch (grund) {
                        'unterbrochen' =>
                          const AbmeldungHinweisKarte.anmeldungUnterbrochen(),
                        'abgelaufen' =>
                          const AbmeldungHinweisKarte.datenAbgelaufen(),
                        'verloren' =>
                          const AbmeldungHinweisKarte.datenAbgelaufen(
                            verloren: 2,
                          ),
                        _ => const AbmeldungHinweisKarte(),
                      },
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.login),
                        label: Text(t.t('auth_login_action')),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  },
);
