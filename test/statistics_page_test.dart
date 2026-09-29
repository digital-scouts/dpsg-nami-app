import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/statistics_page.dart';

void main() {
  testWidgets('zeigt Stammansicht mit Gruppenauswahl', (tester) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    expect(find.text('STAMM TESTDORF - ÜBERSICHT'), findsOneWidget);
    expect(find.text('Meute Nord'), findsOneWidget);
    expect(find.text('GRUPPENVERTEILUNG'), findsOneWidget);
  });

  testWidgets('zeigt keine Global-Ansicht mehr', (tester) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    expect(find.text('Global'), findsNothing);
    expect(find.text('Konfession'), findsNothing);
  });

  testWidgets('oeffnet Gruppendetailseite aus der Gruppenliste', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    await tester.tap(find.text('Meute Nord'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Meute Nord'), findsAtLeastNWidgets(1));
    expect(find.text('Mitglieder'), findsWidgets);
    expect(find.text('ALTERSVERTEILUNG'), findsNothing);
  });
}

Widget _buildTestApp(ArbeitskontextReadModel readModel) {
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
    home: Scaffold(body: StatisticsPage(debugReadModel: readModel)),
  );
}

ArbeitskontextReadModel _buildReadModel() {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Testdorf'),
    ),
    mitglieder: <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1',
        vorname: 'Mara',
        nachname: 'Nord',
      ),
      Mitglied.peopleListItem(
        mitgliedsnummer: '2',
        vorname: 'Lena',
        nachname: 'Leitung',
      ),
    ],
    gruppen: const <ArbeitskontextGruppe>[
      ArbeitskontextGruppe(
        id: 21,
        name: 'Meute Nord',
        layerId: 11,
        gruppenTyp: 'Group::StammGruppeWoelflinge',
      ),
    ],
    mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '1',
        gruppenId: 21,
        rollenLabel: 'Mitglied',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '2',
        gruppenId: 21,
        rollenLabel: 'Hilfsleiter',
      ),
    ],
  );
}
