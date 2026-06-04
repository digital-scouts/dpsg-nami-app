import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/stufen_settings.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/screens/settings_stufenwechsel_page.dart';

void main() {
  Widget buildTestApp({
    required ArbeitskontextReadModel readModel,
    StufenSettings? settings,
    DateTime Function()? todayProvider,
  }) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: SettingsStufenwechselPage(
        debugReadModel: readModel,
        stufenSettingsLoader: () async =>
            settings ??
            StufenSettings(
              grenzen: StufenDefaults.build(),
              stufenwechselDatum: DateTime(2026, 9, 1),
            ),
        todayProvider: todayProvider,
      ),
    );
  }

  Future<void> scrollUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxSwipes = 12,
  }) async {
    for (var i = 0; i < maxSwipes && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt echte Mitglieder im Wechselfenster ohne Auswahl-UI', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(readModel: _readModel()));
    await tester.pumpAndSettle();

    expect(find.text('Emma Mueller'), findsOneWidget);
    expect(find.text('Anna Alt'), findsOneWidget);
    expect(
      find.byKey(const Key('stufenwechsel-member-row-w1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stufenwechsel-member-row-w2')), findsNothing);
    expect(
      find.byKey(const Key('stufenwechsel-member-row-w3')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stufenwechsel-member-row-r1')), findsNothing);
    expect(find.text('Überfällig'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('ausgewählt'), findsNothing);
    expect(find.text('Auswahl übernehmen'), findsNothing);
    expect(find.byKey(const Key('stufenwechsel-rover-section')), findsNothing);
    expect(find.text('Rover erreichen Maximalalter'), findsNothing);
  });

  testWidgets('Tap auf Mitglied oeffnet Mitgliedsdetails mit echtem Mitglied', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(readModel: _readModel()));
    await tester.pumpAndSettle();

    final memberRow = find.byKey(const Key('stufenwechsel-member-row-w1'));
    await scrollUntilFound(tester, memberRow);
    await tester.tap(memberRow);
    await tester.pumpAndSettle();

    expect(find.byType(MemberDetailPage), findsOneWidget);
    expect(find.text('Emma Mueller'), findsWidgets);
  });

  testWidgets('fehlendes Datum nutzt heute und zeigt Warnhinweis', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        readModel: _readModel(),
        settings: StufenSettings(grenzen: StufenDefaults.build()),
        todayProvider: () => DateTime(2026, 6, 4, 15),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stufenwechsel-date-warning')), findsOneWidget);
    expect(find.textContaining('Bitte Datum setzen'), findsOneWidget);
    expect(find.textContaining('Stichtag: 04.06.2026'), findsOneWidget);
  });

  testWidgets('leere Stufen werden ohne Auswahlzeile und Button angezeigt', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(readModel: _readModel()));
    await tester.pumpAndSettle();

    expect(
      find.text('Keine passenden Mitglieder für diese Stufe.'),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.byKey(const Key('stufenwechsel-transfer-row-biber')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('stufenwechsel-transfer-button-biber')),
      findsNothing,
    );
  });

  testWidgets('zeigt Empty-State, wenn keine Wechsel faellig sind', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(readModel: _readModel(mitglieder: const <Mitglied>[])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stufenwechsel-empty-state')), findsOneWidget);
    expect(find.text('Kein Stufenwechsel fällig'), findsOneWidget);
  });
}

ArbeitskontextReadModel _readModel({List<Mitglied>? mitglieder}) {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
    ),
    rolesSindGeladen: true,
    mitglieder:
        mitglieder ??
        <Mitglied>[
          _mitglied(
            id: 'w1',
            vorname: 'Emma',
            nachname: 'Mueller',
            geburtsdatum: DateTime(2017, 7, 1),
            stufe: Stufe.woelfling,
          ),
          _mitglied(
            id: 'w2',
            vorname: 'Leo',
            nachname: 'Jung',
            geburtsdatum: DateTime(2020, 6, 1),
            stufe: Stufe.woelfling,
          ),
          _mitglied(
            id: 'w3',
            vorname: 'Anna',
            nachname: 'Alt',
            geburtsdatum: DateTime(2014, 1, 1),
            stufe: Stufe.woelfling,
          ),
          _mitglied(
            id: 'r1',
            vorname: 'Tim',
            nachname: 'Koch',
            geburtsdatum: DateTime(2004, 1, 1),
            stufe: Stufe.rover,
          ),
        ],
  );
}

Mitglied _mitglied({
  required String id,
  required String vorname,
  required String nachname,
  required DateTime geburtsdatum,
  required Stufe stufe,
}) {
  return Mitglied(
    vorname: vorname,
    nachname: nachname,
    geburtsdatum: geburtsdatum,
    eintrittsdatum: DateTime(2023, 9, 1),
    mitgliedsnummer: id,
    roles: [
      roleFromLegacy(
        stufe: stufe,
        art: RoleCategory.mitglied,
        start: DateTime(2023, 9, 1),
      ),
    ],
  );
}
