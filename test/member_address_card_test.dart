import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
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
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
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

  testWidgets('zeigt Zusatzadressen erst nach dem Aufklappen', (tester) async {
    final member = Mitglied(
      mitgliedsnummer: '4729981',
      vorname: 'Mats',
      nachname: 'Okafor',
      geburtsdatum: DateTime(2018, 5, 9),
      eintrittsdatum: DateTime(2026, 9, 25),
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: 'Am Mühlbach',
          housenumber: '3',
          zipCode: '50999',
          town: 'Köln',
          country: 'DE',
        ),
        MitgliedKontaktAdresse(
          additionalAddressId: 7,
          label: 'Papa',
          street: 'Venloer Straße',
          housenumber: '210',
          zipCode: '50823',
          town: 'Köln',
          country: 'DE',
        ),
        MitgliedKontaktAdresse(
          additionalAddressId: 8,
          label: 'Oma',
          street: 'Kirchweg',
          housenumber: '5',
          zipCode: '53111',
          town: 'Bonn',
          country: 'DE',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemberAddressCard(
              mitglied: member,
              onLaunchAddress: (_) async => true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Am Mühlbach 3, 50999 Köln'), findsOneWidget);
    expect(find.text('Papa'), findsNothing);

    await tester.tap(find.text('2 weitere Adressen'));
    await tester.pump();

    expect(find.text('Venloer Straße 210, 50823 Köln'), findsOneWidget);
    expect(find.text('Papa'), findsOneWidget);
    expect(find.text('Oma'), findsOneWidget);
  });
}
