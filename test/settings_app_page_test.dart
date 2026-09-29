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

  testWidgets('zeigt und schaltet den App-Sperre-Toggle', (tester) async {
    bool? changedValue;
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          biometricLockEnabled: false,
          onBiometricLockChanged: (value) {
            changedValue = value;
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
  });

  testWidgets('zeigt OD-orientierte Abschnittsreihenfolge', (tester) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(buildTestApp(const AppSettingsPage()));
    await tester.pumpAndSettle();

    final security = tester.getTopLeft(
      find.text(localizations.t('settings_app_section_security').toUpperCase()),
    );
    final display = tester.getTopLeft(
      find.text(localizations.t('settings_app_section_display').toUpperCase()),
    );
    final language = tester.getTopLeft(
      find.text(localizations.t('language').toUpperCase()),
    );
    final behavior = tester.getTopLeft(
      find.text(localizations.t('settings_app_section_behavior').toUpperCase()),
    );

    expect(security.dy, lessThan(display.dy));
    expect(display.dy, lessThan(language.dy));
    expect(language.dy, lessThan(behavior.dy));
  });

  testWidgets('schaltet Theme und Sprache ueber Radio-Zeilen', (tester) async {
    ThemeMode? changedTheme;
    String? changedLanguage;
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        AppSettingsPage(
          themeMode: ThemeMode.system,
          languageCode: 'de',
          onThemeModeChanged: (value) => changedTheme = value,
          onLanguageChanged: (value) => changedLanguage = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(localizations.t('settings_app_theme_system')),
      findsOneWidget,
    );
    expect(
      find.text(localizations.t('settings_app_language_en')),
      findsOneWidget,
    );

    await tester.tap(find.text(localizations.t('theme_dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(localizations.t('settings_app_language_en')));
    await tester.pumpAndSettle();

    expect(changedTheme, ThemeMode.dark);
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
