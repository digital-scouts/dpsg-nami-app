import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/demo_zugang_sheet.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story demoZugangSheetStory() => Story(
  name: 'App/Demo/Zugang wählen',
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
    final zeigeSupporter = context.knobs.boolean(
      label: 'Mit Supporter-Zugang',
      initial: false,
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
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DemoZugangSheet(zeigeSupporter: zeigeSupporter),
            ),
          ),
        ),
      ),
    );
  },
);
