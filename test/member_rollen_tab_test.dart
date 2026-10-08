import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/stufen_settings.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_detail/member_rollen_tab.dart';
import 'package:nami/stories/support/mitglied_edge_cases.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  Future<void> zeige(
    WidgetTester tester,
    Mitglied mitglied, {
    String? aktiverLayer,
    StufenSettings? settings,
    bool rollenNichtLesbar = false,
  }) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberRollenTab(
            mitglied: mitglied,
            heute: MitgliedEdgeCases.heute,
            aktiverLayerName: aktiverLayer,
            stufenSettings: settings,
            rollenNichtLesbar: rollenNichtLesbar,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt ohne lesbare Rollen den Hinweis statt leerem Verlauf', (
    tester,
  ) async {
    final ohneRollen = Mitglied.peopleListItem(
      mitgliedsnummer: '1022',
      personId: 22,
      vorname: 'Hanna',
      nachname: 'Albrecht',
    );
    await zeige(tester, ohneRollen, rollenNichtLesbar: true);

    expect(
      find.text(
        'Die Rollen dieser Person liefert Hitobito mit deinen Rechten nicht.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blendet Rollen anderer Layer standardmaessig aus', (
    tester,
  ) async {
    await zeige(
      tester,
      MitgliedEdgeCases.funke,
      aktiverLayer: MitgliedEdgeCases.stamm,
    );

    expect(find.text('12 (3 ausgeblendet)'), findsOneWidget);
    expect(
      find.text('3 Rollen aus DV und Bezirk ausgeblendet'),
      findsOneWidget,
    );
    expect(find.text('AK Leiter*in'), findsNothing);

    await tester.tap(find.byKey(const Key('rollen-layer-filter')));
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
    expect(find.text('AK Leiter*in'), findsOneWidget);
    expect(find.text('DV'), findsWidgets);
    expect(find.text('Nur Stamm Silberfels'), findsOneWidget);
  });

  testWidgets('zeigt ohne fremde Layer keinen Filter', (tester) async {
    await zeige(
      tester,
      MitgliedEdgeCases.jonas,
      aktiverLayer: MitgliedEdgeCases.stamm,
    );

    expect(find.byKey(const Key('rollen-layer-filter')), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('klappt aeltere Jahre ein und wieder auf', (tester) async {
    await zeige(tester, MitgliedEdgeCases.funke);

    expect(find.text('Wölfling'), findsNothing);
    await tester.tap(find.text('7 frühere Jahre anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('Wölfling'), findsOneWidget);
    expect(find.text('Weniger anzeigen'), findsOneWidget);
  });

  testWidgets('zeigt Kindern ohne Leitung den naechsten Stufenwechsel', (
    tester,
  ) async {
    await zeige(tester, MitgliedEdgeCases.mats);

    expect(find.text('ab 2027'), findsOneWidget);
    expect(find.text('zu den Jufis'), findsOneWidget);
    expect(find.text('Der Verlauf wächst mit jeder Stufe.'), findsOneWidget);
  });

  testWidgets('nutzt eingestellte Altersgrenzen fuer den Stufenwechsel', (
    tester,
  ) async {
    final grenzen = StufenDefaults.build().copyWithFor(
      Stufe.jungpfadfinder,
      const AltersIntervall(minJahre: 8, maxJahre: 13),
    );
    await zeige(
      tester,
      MitgliedEdgeCases.mats,
      settings: StufenSettings(grenzen: grenzen),
    );

    expect(find.text('bis 2028'), findsOneWidget);
  });

  testWidgets('Leitende behalten die Leitungs-Kachel', (tester) async {
    await zeige(tester, MitgliedEdgeCases.sami);

    expect(find.text('in der Leitung'), findsOneWidget);
    expect(find.text('Stufenwechsel'), findsNothing);
  });

  testWidgets(
    'markiert fehlende fruehere Rollen und bricht ohne Rollen nicht',
    (tester) async {
      final nurAktuell = MitgliedEdgeCases.funke.copyWith(
        roles: MitgliedEdgeCases.funke.roles
            .where((r) => r.endOn == null)
            .toList(),
      );
      await zeige(tester, nurAktuell);
      expect(find.text('früher, noch nicht abrufbar'), findsOneWidget);
      expect(
        find.text('Frühere Rollen liefert Hitobito noch nicht.'),
        findsOneWidget,
      );

      await zeige(
        tester,
        MitgliedEdgeCases.mats.copyWith(roles: const <Role>[]),
      );
      expect(find.text('Keine Rollen'), findsOneWidget);
    },
  );
}
