import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/hilfe_diagnose_page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/problem_melden_sheet.dart';
import 'package:nami/stories/profile_page_story.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Widget _app({required bool dark, required Widget home}) => MaterialApp(
  theme: buildTheme(AppPaletteId.standard, Brightness.light),
  darkTheme: buildTheme(AppPaletteId.standard, Brightness.dark),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    AppLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: home,
);

/// „Hilfe & Diagnose“ im Release und mit Entwickler-Werkzeugen (A-94).
Story hilfeDiagnoseStory() => Story(
  name: 'Einstellungen/Screens/Hilfe & Diagnose',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final entwickler = context.knobs.boolean(
      label: 'Debug/Profile-Build',
      initial: false,
    );
    final angemeldet = context.knobs.boolean(
      label: 'Angemeldet',
      initial: true,
    );
    return StorySignedInScope(
      profile: angemeldet
          ? const AuthProfile(namiId: 7, firstName: 'Mara', lastName: 'Muster')
          : null,
      child: _app(
        dark: dark,
        home: HilfeDiagnosePage(entwicklerFunktionen: entwickler),
      ),
    );
  },
);

/// Sheet „Problem melden“ vor der Mail (Entwurf Runde 3, D2).
Story problemMeldenSheetStory() => Story(
  name: 'Einstellungen/Widgets/Problem melden',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    return _app(
      dark: dark,
      home: const Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ProblemMeldenSheet(),
          ),
        ),
      ),
    );
  },
);
