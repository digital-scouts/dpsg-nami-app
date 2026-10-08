import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/neuanmeldung_sheet.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story neuanmeldungSheetStory() => Story(
  name: 'App/Login/Rückfrage Neuanmeldung',
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
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: const Padding(
              padding: EdgeInsets.only(top: 24),
              child: NeuanmeldungSheet(),
            ),
          ),
        ),
      ),
    );
  },
);
