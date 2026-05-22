import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/statistics_page.dart';

void main() {
  testWidgets('zeigt Stammansicht mit Gruppenauswahl', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    expect(find.text('Stamm St. Georg - Uebersicht'), findsOneWidget);
    expect(find.text('Rudel Silberpfeil'), findsOneWidget);
    expect(find.text('Gruppenverteilung'), findsOneWidget);
  });

  testWidgets('zeigt Global als gesperrte Opt-in-Ansicht ohne Skip', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('Global'));
    await tester.pumpAndSettle();

    expect(find.text('Bundesweite Statistik'), findsOneWidget);
    expect(find.textContaining('Kein Skip-Pfad'), findsOneWidget);
    expect(find.text('Opt-in folgt in Phase 2'), findsOneWidget);
  });

  testWidgets('oeffnet Gruppendetailseite aus der Gruppenliste', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('Rudel Silberpfeil'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Rudel Silberpfeil'), findsAtLeastNWidgets(1));
    expect(find.text('Mitglieder'), findsWidgets);
    expect(find.text('Altersverteilung'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return MaterialApp(
    onGenerateRoute: onGenerateRoute,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    locale: const Locale('de'),
    home: const Scaffold(body: StatisticsPage()),
  );
}
