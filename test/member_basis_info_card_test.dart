import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/member/mitglied.dart';
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
        home: Scaffold(body: MemberGeneralInfoCard(mitglied: member)),
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
}
