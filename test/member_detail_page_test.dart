import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets('rendert Read-only-Details fuer ein Mitglied', (tester) async {
    final member = Mitglied(
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      updatedAt: DateTime(2024, 11, 7, 14, 35),
      telefonnummern: const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(wert: '040123456', label: 'Festnetznummer'),
      ],
      emailAdressen: const <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(wert: 'julia@example.com', label: 'E-Mail'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: MemberDetailPage(mitglied: member)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Julia Keller'), findsOneWidget);
    expect(find.text('Allgemeine Informationen'), findsOneWidget);
    expect(find.text('Mitgliedschaft'), findsOneWidget);
    expect(find.text('4711'), findsOneWidget);
    expect(find.text('Zuletzt aktualisiert'), findsOneWidget);
    expect(find.text('07.11.2024, 14:35'), findsOneWidget);
  });

  testWidgets('blendet Platzhalterdaten fuer Geburtstag und Eintritt aus', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '9',
      vorname: 'Max',
      nachname: 'Mustermann',
    );

    await tester.pumpWidget(
      MaterialApp(home: MemberDetailPage(mitglied: member)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Geburtstag'), findsNothing);
    expect(find.text('Eintrittsdatum'), findsNothing);
    expect(find.text('Mitgliedschaft'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });
}
