import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/mobile_daten_hinweis.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story mobileDatenHinweisStory() => Story(
  name: 'App/Mobile Daten/Hinweis',
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
    final art = context.knobs.options<String>(
      label: 'Art',
      initial: 'karte',
      options: const [
        Option(label: 'Karte', value: 'karte'),
        Option(label: 'Kleine Karte', value: 'kompakt'),
        Option(label: 'Adresssuche', value: 'adresse'),
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
                  final adresse = art == 'adresse';
                  return MobileDatenHinweis(
                    icon: adresse ? Icons.search : Icons.signal_cellular_alt,
                    titel: t.t(
                      adresse
                          ? 'mobile_daten_adresse_titel'
                          : 'mobile_daten_karte_titel',
                    ),
                    text: t.t(
                      adresse
                          ? 'mobile_daten_adresse_text'
                          : 'mobile_daten_karte_text',
                    ),
                    knopf: t.t(
                      adresse
                          ? 'mobile_daten_adresse_laden'
                          : 'mobile_daten_laden',
                    ),
                    kompakt: art == 'kompakt',
                    onLaden: () {},
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
