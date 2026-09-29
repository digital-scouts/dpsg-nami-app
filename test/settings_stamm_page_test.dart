import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_stamm_page.dart';

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

  testWidgets('zeigt OD-Kartenlayout mit Adresse und Stufenwechsel', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        SettingsStammPage(
          addressRepository: InMemoryAddressSettingsRepository(),
          initialAltersgrenzen: StufenDefaults.build(),
          initialStufenwechsel: null,
          onSaveAltersgrenzen: (_) {},
          onStufenwechselChanged: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Prüfe, dass beide Kartensektion-Label vorhanden sind
    expect(
      find.text(localizations.t('address_section').toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(localizations.t('stufenwechsel_section').toUpperCase()),
      findsOneWidget,
    );

    // Prüfe, dass Beschreibungstexte vorhanden sind
    expect(find.text(localizations.t('address_help')), findsOneWidget);
    expect(find.text(localizations.t('stufenwechsel_help')), findsOneWidget);
  });

  testWidgets('Datums-Zeile ist sichtbar und kann geklickt werden', (
    tester,
  ) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        SettingsStammPage(
          addressRepository: InMemoryAddressSettingsRepository(),
          initialAltersgrenzen: StufenDefaults.build(),
          initialStufenwechsel: null,
          onSaveAltersgrenzen: (_) {},
          onStufenwechselChanged: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Prüfe, dass Datumstitel in separater StufenwechselDateRow Card vorhanden ist
    expect(
      find.text(localizations.t('stufenwechsel_date_title')),
      findsOneWidget,
    );
    expect(
      find.text(localizations.t('stufenwechsel_date_hint')),
      findsOneWidget,
    );

    // Prüfe, dass Kalender-Icon vorhanden ist
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);

    // Prüfe, dass die Datums-Zeile tappbar ist
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
  });

  testWidgets('Reset und Save Buttons sind sichtbar', (tester) async {
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      buildTestApp(
        SettingsStammPage(
          addressRepository: InMemoryAddressSettingsRepository(),
          initialAltersgrenzen: StufenDefaults.build(),
          initialStufenwechsel: null,
          onSaveAltersgrenzen: (_) {},
          onStufenwechselChanged: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Prüfe, dass Reset und Save sichtbar sind (in separater Header-Row)
    expect(find.byIcon(Icons.restore), findsOneWidget);
    expect(find.text(localizations.t('save')), findsOneWidget);

    // Prüfe, dass Altersgruppen-Label vorhanden ist
    expect(
      find.text(localizations.t('altersgruppen').toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('Toggle zwischen Slider und MinMax Variante funktioniert', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        SettingsStammPage(
          addressRepository: InMemoryAddressSettingsRepository(),
          initialAltersgrenzen: StufenDefaults.build(),
          initialStufenwechsel: null,
          onSaveAltersgrenzen: (_) {},
          onStufenwechselChanged: (_) {},
          useMinMaxVariant: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial sollte Slider-Ansicht aktiv sein (SfRangeSlider)
    expect(find.byIcon(Icons.view_list), findsOneWidget);
    expect(find.text('Biber'), findsNothing);

    // Toggle drücken
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    // Jetzt sollte MinMax-Ansicht aktiv sein
    expect(find.byIcon(Icons.straighten), findsOneWidget);
    expect(find.text('Biber'), findsOneWidget);
    expect(find.text('Rover'), findsOneWidget);
  });
}
