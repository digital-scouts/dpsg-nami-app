import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_basis_info_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets('copy icon wird beim Kopieren kurz gruen hervorgehoben', (
    tester,
  ) async {
    final member = Mitglied(
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      telefonnummern: const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(wert: '+4940123456', label: 'Festnetznummer'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(body: MemberContactInfoCard(mitglied: member)),
      ),
    );

    final copyIconFinder = find.byIcon(Icons.copy);
    final highlightFinder = find.byKey(
      const ValueKey('copy-highlight-container'),
    );

    expect(copyIconFinder, findsOneWidget);
    expect(highlightFinder, findsOneWidget);

    BoxDecoration highlightDecoration() =>
        tester.widget<AnimatedContainer>(highlightFinder).decoration!
            as BoxDecoration;

    expect(highlightDecoration().color, Colors.transparent);

    await tester.tap(find.byTooltip('Kopieren'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(highlightDecoration().color, isNot(Colors.transparent));
    expect(find.text('Kopiert'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));

    expect(highlightDecoration().color, Colors.transparent);
  });

  testWidgets(
    'zeigt Beitragsart als reine Anzeige in der Mitgliedschaftskarte',
    (tester) async {
      final member = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: Scaffold(
            body: MemberMembershipInfoCard(
              mitglied: member,
              beitragsart: Beitragsart.foerdermitgliedschaft,
              stammNamen: const <String>['Mauersegler'],
              gruppenNamen: const <String>['Schnabeltiere'],
            ),
          ),
        ),
      );

      expect(find.text('Beitragsart'), findsOneWidget);
      expect(find.text('Foerdermitgliedschaft'), findsOneWidget);
      expect(find.text('Stamm'), findsOneWidget);
      expect(find.text('Mauersegler'), findsOneWidget);
      expect(find.text('Gruppe'), findsOneWidget);
      expect(find.text('Schnabeltiere'), findsOneWidget);
    },
  );

  testWidgets('zeigt Geschlecht und vorhandene Pronomen in den Basisdaten', (
    tester,
  ) async {
    final member = Mitglied(
      mitgliedsnummer: '5001',
      vorname: 'Alex',
      nachname: 'Beispiel',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      gender: 'w',
      pronoun: 'sie/ihr',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(body: MemberGeneralInfoCard(mitglied: member)),
      ),
    );

    expect(find.text('Geschlecht'), findsOneWidget);
    expect(find.text('Weiblich'), findsOneWidget);
    expect(find.text('Pronomen'), findsOneWidget);
    expect(find.text('sie/ihr'), findsOneWidget);
  });

  testWidgets('blendet Pronomen aus, wenn kein Wert vorhanden ist', (
    tester,
  ) async {
    final member = Mitglied(
      mitgliedsnummer: '5002',
      vorname: 'Sam',
      nachname: 'Beispiel',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      gender: null,
      pronoun: '   ',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(body: MemberGeneralInfoCard(mitglied: member)),
      ),
    );

    expect(find.text('Geschlecht'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('Pronomen'), findsNothing);
  });

  testWidgets('zeigt bei fehlendem Stamm und Gruppe jeweils einen Strich', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4712',
      vorname: 'Mara',
      nachname: 'Schmidt',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberMembershipInfoCard(
            mitglied: member,
            beitragsart: null,
            stammNamen: const <String>[],
            gruppenNamen: const <String>['   '],
          ),
        ),
      ),
    );

    expect(find.text('Beitragsart'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(3));
  });

  testWidgets('zeigt mehrere Gruppen als kommaseparierte Liste', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4713',
      vorname: 'Tom',
      nachname: 'Tester',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberMembershipInfoCard(
            mitglied: member,
            stammNamen: const <String>['Mauersegler', 'Bussarde'],
            gruppenNamen: const <String>['Schnabeltiere', 'Wiesel'],
          ),
        ),
      ),
    );

    expect(find.text('Mauersegler, Bussarde'), findsOneWidget);
    expect(find.text('Schnabeltiere, Wiesel'), findsOneWidget);
  });
}
