import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: child,
    );
  }

  Switch appSperreSchalter(WidgetTester tester) {
    final localizations = AppLocalizations(const Locale('de'));
    return tester.widget<Switch>(
      find.descendant(
        of: find.ancestor(
          of: find.text(localizations.t('settings_app_lock_title')),
          matching: find.byType(InkWell),
        ),
        matching: find.byType(Switch),
      ),
    );
  }

  testWidgets('zeigt und schaltet den App-Sperre-Toggle', (tester) async {
    bool? changedValue;
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          biometricLockEnabled: false,
          appSperreVerfuegbar: () async => true,
          onBiometricLockChanged: (value) async {
            changedValue = value;
            return value;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(localizations.t('settings_app_lock_title')),
      findsOneWidget,
    );
    expect(
      find.text(localizations.t('settings_app_lock_hint')),
      findsOneWidget,
    );

    await tester.tap(find.text(localizations.t('settings_app_lock_title')));
    await tester.pumpAndSettle();

    expect(changedValue, isTrue);
    expect(appSperreSchalter(tester).value, isTrue);
  });

  testWidgets('bietet die App-Sperre ohne Geraetesicherung nicht an', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          biometricLockEnabled: false,
          appSperreVerfuegbar: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(localizations.t('settings_app_lock_title')), findsNothing);
  });

  testWidgets('laesst eine aktive Sperre ohne Geraetesicherung abschaltbar', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          biometricLockEnabled: true,
          appSperreVerfuegbar: () async => false,
          onBiometricLockChanged: (value) async => value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(localizations.t('settings_app_lock_title')),
      findsOneWidget,
    );

    await tester.tap(find.text(localizations.t('settings_app_lock_title')));
    await tester.pumpAndSettle();

    // Abgeschaltet und ohne Geraetesicherung wird sie nicht mehr angeboten.
    expect(find.text(localizations.t('settings_app_lock_title')), findsNothing);
  });

  testWidgets('uebernimmt den Wert der Bestaetigung fuer die App-Sperre', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));
    final angefragt = <bool>[];
    var bestaetigt = false;

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          biometricLockEnabled: false,
          appSperreVerfuegbar: () async => true,
          onBiometricLockChanged: (value) async {
            angefragt.add(value);
            return bestaetigt ? value : !value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abgebrochene Probe-Entsperrung: Sperre bleibt aus.
    await tester.tap(find.text(localizations.t('settings_app_lock_title')));
    await tester.pumpAndSettle();
    expect(angefragt, [true]);
    expect(appSperreSchalter(tester).value, isFalse);

    bestaetigt = true;
    await tester.tap(find.text(localizations.t('settings_app_lock_title')));
    await tester.pumpAndSettle();
    expect(appSperreSchalter(tester).value, isTrue);

    // Abgebrochene Bestaetigung beim Abschalten: Sperre bleibt an.
    bestaetigt = false;
    await tester.tap(find.text(localizations.t('settings_app_lock_title')));
    await tester.pumpAndSettle();
    expect(angefragt, [true, true, false]);
    expect(appSperreSchalter(tester).value, isTrue);
  });

  testWidgets('zeigt OD-orientierte Abschnittsreihenfolge', (tester) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(buildTestApp(const AppSettingsPage()));
    await tester.pumpAndSettle();

    final security = tester.getTopLeft(
      find.text(localizations.t('settings_app_section_security').toUpperCase()),
    );
    final language = tester.getTopLeft(
      find.text(localizations.t('language').toUpperCase()),
    );
    final behavior = tester.getTopLeft(
      find.text(localizations.t('settings_app_section_behavior').toUpperCase()),
    );

    expect(security.dy, lessThan(language.dy));
    expect(language.dy, lessThan(behavior.dy));
    // Hell/Dunkel ist in das Erscheinungsbild umgezogen.
    expect(
      find.text(localizations.t('settings_app_section_display').toUpperCase()),
      findsNothing,
    );
  });

  testWidgets('schaltet die Sprache ueber Radio-Zeilen', (tester) async {
    String? changedLanguage;
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          languageCode: 'de',
          onLanguageChanged: (value) => changedLanguage = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(localizations.t('settings_app_language_en')));
    await tester.pumpAndSettle();

    expect(changedLanguage, 'en');
  });

  testWidgets(
    'zeigt den Bundesstatistik-Schalter nur bei verfuegbarem Server',
    (tester) async {
      final localizations = AppLocalizations(const Locale('de'));
      await tester.pumpWidget(buildTestApp(const AppSettingsPage()));
      await tester.pumpAndSettle();

      expect(
        find.text(localizations.t('settings_app_bundesstatistik_title')),
        findsNothing,
      );

      await tester.pumpWidget(
        buildTestApp(const AppSettingsPage(bundesstatistikVerfuegbar: true)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(localizations.t('settings_app_bundesstatistik_title')),
        findsOneWidget,
      );
    },
  );

  testWidgets('uebernimmt den tatsaechlichen Wert nach der Einwilligung', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));
    final angefragt = <bool>[];
    var ergebnis = false;
    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          bundesstatistikVerfuegbar: true,
          onBundesstatistikChanged: (value) async {
            angefragt.add(value);
            return ergebnis;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    Switch schalter() => tester.widget<Switch>(
      find.descendant(
        of: find.ancestor(
          of: find.text(localizations.t('settings_app_bundesstatistik_title')),
          matching: find.byType(InkWell),
        ),
        matching: find.byType(Switch),
      ),
    );

    // Abgelehnte Einwilligung: Schalter bleibt aus.
    await tester.tap(
      find.text(localizations.t('settings_app_bundesstatistik_title')),
    );
    await tester.pumpAndSettle();
    expect(angefragt, [true]);
    expect(schalter().value, isFalse);

    ergebnis = true;
    await tester.tap(
      find.text(localizations.t('settings_app_bundesstatistik_title')),
    );
    await tester.pumpAndSettle();
    expect(schalter().value, isTrue);
  });
}
