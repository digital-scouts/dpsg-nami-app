import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_address_card.dart';

void main() {
  test('formatiert kompakte Adressanzeige ohne care of und postbox', () {
    const address = MitgliedKontaktAdresse(
      street: 'Musterweg',
      housenumber: '4',
      zipCode: '50667',
      town: 'Koeln',
      country: 'DE',
      addressCareOf: 'c/o Beispiel',
      postbox: '123',
    );

    expect(
      MemberAddressUtils.formatCompactDisplayAddress(address),
      'Musterweg 4, 50667 Koeln',
    );
  });

  test('laesst fehlende Hausnummer in kompakter Anzeige einfach weg', () {
    const address = MitgliedKontaktAdresse(
      street: 'Musterweg',
      zipCode: '50667',
      town: 'Koeln',
      country: 'DE',
    );

    expect(
      MemberAddressUtils.formatCompactDisplayAddress(address),
      'Musterweg, 50667 Koeln',
    );
  });

  testWidgets('nur der Adresstext ist klickbar und startet Karten-Launch', (
    tester,
  ) async {
    var launchedQuery = '';
    final member = Mitglied(
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: 'Musterweg',
          housenumber: '4',
          zipCode: '50667',
          town: 'Koeln',
          country: 'DE',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberAddressCard(
            mitglied: member,
            onLaunchAddress: (addressQuery) async {
              launchedQuery = addressQuery;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Musterweg 4, 50667 Koeln'));
    await tester.pump();

    expect(launchedQuery, 'Musterweg 4, 50667 Koeln, DE');
  });
}
