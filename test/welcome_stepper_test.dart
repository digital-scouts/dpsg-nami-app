import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';

class _Aufrufe {
  var biometrie = 0;
  var benachrichtigungen = 0;
  final analyse = <bool>[];
  final mobil = <bool>[];
  final themes = <ThemeMode>[];
  var rechtliches = 0;
  var systemEinstellungen = 0;
}

WillkommenOptionen _optionen(
  _Aufrufe aufrufe, {
  bool biometrieVerfuegbar = true,
  bool biometrieOk = true,
  bool benachrichtigungenOk = true,
}) => WillkommenOptionen(
  biometrieVerfuegbar: biometrieVerfuegbar,
  biometrieAktiv: false,
  benachrichtigungenErlaubt: null,
  analyseAktiv: false,
  keineMobilenDaten: false,
  themeMode: ThemeMode.system,
  onBiometrieAktivieren: () async {
    aufrufe.biometrie++;
    return biometrieOk;
  },
  onBenachrichtigungenAktivieren: () async {
    aufrufe.benachrichtigungen++;
    return benachrichtigungenOk;
  },
  onAnalyseAendern: (v) async => aufrufe.analyse.add(v),
  onKeineMobilenDatenAendern: (v) async => aufrufe.mobil.add(v),
  onThemeAendern: (v) async => aufrufe.themes.add(v),
  onRechtliches: () => aufrufe.rechtliches++,
  onSystemEinstellungen: () => aufrufe.systemEinstellungen++,
);

Widget _app(Widget Function(BuildContext) home) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: Builder(builder: home),
);

Future<void> _tippe(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
}

Future<void> _starte(WidgetTester tester, WillkommenOptionen optionen) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      (context) => TextButton(
        onPressed: () => showWelcomeDialog(context, optionen: optionen),
        child: const Text('start'),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Erlaubnisse führen automatisch zum nächsten Schritt', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    await _starte(tester, _optionen(aufrufe));

    expect(find.text('Schritt 1 von 4'), findsOneWidget);
    expect(find.text('App schützen'), findsOneWidget);
    expect(find.textContaining('verliehen wird'), findsOneWidget);
    await _tippe(tester, const Key('welcome-lock-on'));
    await tester.pump();
    expect(find.text('Aktiv'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(aufrufe.biometrie, 1);

    expect(find.text('Schritt 2 von 4'), findsOneWidget);
    expect(find.textContaining('Führungszeugnis'), findsOneWidget);
    expect(find.textContaining('Geburtstage'), findsWidgets);
    await _tippe(tester, const Key('welcome-notify-on'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(aufrufe.benachrichtigungen, 1);

    expect(find.text('Schritt 3 von 4'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
    await tester.ensureVisible(find.text('Dunkel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dunkel'));
    await _tippe(tester, const Key('welcome-analytics'));
    await _tippe(tester, const Key('welcome-no-mobile-data'));
    await _tippe(tester, const Key('welcome-legal'));
    await tester.pumpAndSettle();
    expect(aufrufe.themes, [ThemeMode.dark]);
    expect(aufrufe.analyse, [true]);
    expect(aufrufe.mobil, [true]);
    expect(aufrufe.rechtliches, 1);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 4 von 4'), findsOneWidget);
    for (final key in [
      'members',
      'offline',
      'statistics',
      'stage_change',
      'qualifications',
      'layers',
    ]) {
      expect(find.byKey(Key('welcome-highlight-$key')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('welcome-finish')));
    await tester.pumpAndSettle();
    expect(find.byType(WillkommenStepper), findsNothing);
  });

  testWidgets('abgelehnte Benachrichtigungen bleiben mit Hinweis stehen', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    await _starte(
      tester,
      _optionen(
        aufrufe,
        biometrieVerfuegbar: false,
        benachrichtigungenOk: false,
      ),
    );

    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    expect(find.text('Benachrichtigungen'), findsWidgets);
    await _tippe(tester, const Key('welcome-notify-on'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    expect(find.text('Aus'), findsOneWidget);
    expect(find.textContaining('Nicht erlaubt'), findsOneWidget);
    await _tippe(tester, const Key('welcome-notify-settings'));
    expect(aufrufe.systemEinstellungen, 1);
  });

  testWidgets('abgebrochene Face-ID-Bestätigung geht nicht weiter', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    await _starte(tester, _optionen(aufrufe, biometrieOk: false));

    await _tippe(tester, const Key('welcome-lock-on'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Schritt 1 von 4'), findsOneWidget);
    expect(find.byKey(const Key('welcome-lock-on')), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-back')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 4'), findsOneWidget);
  });
}
