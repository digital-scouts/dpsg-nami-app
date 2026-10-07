import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';

class _Aufrufe {
  final biometrie = <bool>[];
  final analyse = <bool>[];
  final mobil = <bool>[];
  var rechtliches = 0;
}

WillkommenOptionen _optionen(_Aufrufe aufrufe, {bool biometrie = true}) =>
    WillkommenOptionen(
      biometrieVerfuegbar: biometrie,
      biometrieAktiv: false,
      analyseAktiv: false,
      keineMobilenDaten: false,
      onBiometrieAendern: (v) async => aufrufe.biometrie.add(v),
      onAnalyseAendern: (v) async => aufrufe.analyse.add(v),
      onKeineMobilenDatenAendern: (v) async => aufrufe.mobil.add(v),
      onRechtliches: () => aufrufe.rechtliches++,
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

void main() {
  testWidgets('führt durch drei Schritte und liefert die Einführungswahl', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    bool? ergebnis;
    await tester.pumpWidget(
      _app(
        (context) => TextButton(
          onPressed: () async => ergebnis = await showWelcomeDialog(
            context,
            optionen: _optionen(aufrufe),
          ),
          child: const Text('start'),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    expect(find.text('App schützen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome-lock-on')));
    await tester.pumpAndSettle();
    expect(aufrufe.biometrie, [true]);
    expect(find.text('Aktiv'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    final analyse = tester.widget<Switch>(
      find.byKey(const Key('welcome-analytics')),
    );
    expect(analyse.value, isFalse);
    await tester.tap(find.byKey(const Key('welcome-analytics')));
    await tester.tap(find.byKey(const Key('welcome-no-mobile-data')));
    await tester.tap(find.byKey(const Key('welcome-legal')));
    await tester.pumpAndSettle();
    expect(aufrufe.analyse, [true]);
    expect(aufrufe.mobil, [true]);
    expect(aufrufe.rechtliches, 1);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Kurze Einführung?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome-intro-yes')));
    await tester.pumpAndSettle();

    expect(ergebnis, isTrue);
    expect(find.byType(WillkommenStepper), findsNothing);
  });

  testWidgets('ohne Biometrie nur zwei Schritte, Zurück funktioniert', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    bool? ergebnis;
    await tester.pumpWidget(
      _app(
        (context) => TextButton(
          onPressed: () async => ergebnis = await showWelcomeDialog(
            context,
            optionen: _optionen(aufrufe, biometrie: false),
          ),
          child: const Text('start'),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 1 von 2'), findsOneWidget);
    expect(find.text('Daten und Datenschutz'), findsOneWidget);
    expect(find.byKey(const Key('welcome-back')), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-back')));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-intro-no')));
    await tester.pumpAndSettle();
    expect(ergebnis, isFalse);
    expect(aufrufe.biometrie, isEmpty);
  });
}
