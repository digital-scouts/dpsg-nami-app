import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';

void main() {
  test('akzeptiert leeren Vor- und Nachnamen als fehlende People-Felder', () {
    final mitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '1234',
      vorname: '',
      nachname: '',
    );

    expect(mitglied.vorname, isEmpty);
    expect(mitglied.nachname, isEmpty);
    expect(mitglied.fullName, isEmpty);
  });

  test('normalisiert strukturierte Kontaktobjekte ohne Legacy-Felder', () {
    final mitglied = Mitglied(
      mitgliedsnummer: '1001',
      vorname: 'Anna',
      nachname: 'Beispiel',
      geburtsdatum: DateTime(2010, 4, 3),
      eintrittsdatum: DateTime(2021, 9, 1),
      telefonnummern: const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(
          wert: '+49 170 1234567',
          label: Mitglied.phoneMobileLabel,
        ),
      ],
      emailAdressen: const <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: 'anna@example.org',
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
        MitgliedKontaktEmail(
          wert: 'familie@example.org',
          label: Mitglied.secondaryEmailLabel,
        ),
      ],
    );

    expect(mitglied.telefonnummern, const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        wert: '+49 170 1234567',
        label: Mitglied.phoneMobileLabel,
      ),
    ]);
    expect(mitglied.emailAdressen, const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'anna@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(
        wert: 'familie@example.org',
        label: Mitglied.secondaryEmailLabel,
      ),
    ]);
  });

  test('serialisiert und deserialisiert das erweiterte Personenmodell', () {
    final original = Mitglied(
      personId: 77,
      mitgliedsnummer: '1002',
      vorname: 'Max',
      nachname: 'Muster',
      geburtsdatum: DateTime(2008, 6, 2),
      eintrittsdatum: DateTime(2020, 1, 1),
      austrittsdatum: DateTime(2025, 2, 1),
      updatedAt: DateTime(2025, 3, 4, 16, 30),
      picture: 'https://example.org/picture.svg',
      pronoun: 'er/ihm',
      bankAccountOwner: 'Max Muster',
      iban: 'DE02120300000000202051',
      bic: 'BYLADEM1001',
      bankName: 'Testbank',
      paymentMethod: 'lsv',
      emailAdressen: const <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: 'max@example.org',
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
      ],
      telefonnummern: const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(
          wert: '+49 30 123456',
          label: Mitglied.phoneLandlineLabel,
        ),
      ],
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          addressCareOf: 'c/o Muster',
          street: 'Ringstrasse',
          housenumber: '2',
          postbox: 'PF 77',
          zipCode: '50667',
          town: 'Koeln',
          country: 'DE',
        ),
      ],
    );

    final decoded = Mitglied.fromPeopleListJson(original.toPeopleListJson());

    expect(decoded, original);
  });

  group('primaryAddress und additionalAddresses', () {
    const hauptadresse = MitgliedKontaktAdresse(
      additionalAddressId: 0,
      street: 'Ringstrasse',
      housenumber: '2',
      zipCode: '50667',
      town: 'Koeln',
    );
    const zusatzadresse = MitgliedKontaktAdresse(
      additionalAddressId: 41,
      label: 'Oma',
      street: 'Nebenweg',
      zipCode: '20095',
      town: 'Hamburg',
    );
    const neueAdresse = MitgliedKontaktAdresse(street: 'Neuweg', town: 'Bonn');

    Mitglied mitgliedMit(List<MitgliedKontaktAdresse> adressen) {
      return Mitglied.peopleListItem(
        mitgliedsnummer: '1003',
        personId: 88,
        vorname: 'Lea',
        nachname: 'Muster',
        adressen: adressen,
      );
    }

    test('liefert Hauptadresse ueber id 0 unabhaengig von der Position', () {
      final mitglied = mitgliedMit(const <MitgliedKontaktAdresse>[
        zusatzadresse,
        hauptadresse,
        neueAdresse,
      ]);

      expect(mitglied.primaryAddress, hauptadresse);
      expect(mitglied.additionalAddresses, [zusatzadresse, neueAdresse]);
      expect(mitglied.primaryAddressCacheKey, '88:0');
    });

    test('liefert ohne Adressen weder Haupt- noch Zusatzadressen', () {
      final mitglied = mitgliedMit(const <MitgliedKontaktAdresse>[]);

      expect(mitglied.primaryAddress, isNull);
      expect(mitglied.additionalAddresses, isEmpty);
      expect(mitglied.primaryAddressCacheKey, isNull);
    });

    test('macht bei fehlender Hauptadresse keine Zusatzadresse zur '
        'Hauptadresse', () {
      final mitglied = mitgliedMit(const <MitgliedKontaktAdresse>[
        zusatzadresse,
        neueAdresse,
      ]);

      expect(mitglied.primaryAddress, isNull);
      expect(mitglied.additionalAddresses, [zusatzadresse, neueAdresse]);
      expect(mitglied.primaryAddressCacheKey, isNull);
    });

    test('behandelt geleerte Hauptadresse als fehlend', () {
      final mitglied = mitgliedMit(const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(additionalAddressId: 0, street: '  '),
        zusatzadresse,
      ]);

      expect(mitglied.adressen, [zusatzadresse]);
      expect(mitglied.primaryAddress, isNull);
      expect(mitglied.additionalAddresses, [zusatzadresse]);
    });
  });
}
