import 'package:flutter_test/flutter_test.dart';
import 'package:nami/utilities/helper_functions.dart';

void main() {
  group('getAlterAm', () {
    test('berechnet das Alter korrekt am Geburtstag', () {
      // Geburtstag: 15. März 1995
      final geburtstag = DateTime(1995, 3, 15);
      // Referenzdatum: 15. März 2023 (28. Geburtstag)
      final referenzdatum = DateTime(2023, 3, 15);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(28));
      expect(alter, greaterThanOrEqualTo(28.0));
      expect(alter, lessThan(28.1));
    });

    test('berechnet das Alter korrekt einen Tag vor dem Geburtstag', () {
      // Geburtstag: 15. März 1995
      final geburtstag = DateTime(1995, 3, 15);
      // Referenzdatum: 14. März 2023 (noch 27)
      final referenzdatum = DateTime(2023, 3, 14);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(27));
      expect(alter, greaterThan(27.9)); // fast 28, aber noch nicht ganz
    });

    test('berechnet das Alter korrekt einen Tag nach dem Geburtstag', () {
      // Geburtstag: 15. März 1995
      final geburtstag = DateTime(1995, 3, 15);
      // Referenzdatum: 16. März 2023 (28 + 1 Tag)
      final referenzdatum = DateTime(2023, 3, 16);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(28));
      expect(alter, greaterThan(28.0));
      expect(alter, lessThan(28.1));
    });

    test('berechnet das Alter korrekt bei Schaltjahren', () {
      // Geburtstag: 29. Februar 2000 (Schaltjahr)
      final geburtstag = DateTime(2000, 2, 29);
      // Referenzdatum: 28. Februar 2023 (kein Schaltjahr, noch nicht 23)
      final referenzdatum = DateTime(2023, 2, 28);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(
        alter.floor(),
        equals(22),
      ); // noch nicht 23, da 29. Feb nicht existiert
    });

    test(
      'berechnet das Alter korrekt am 1. März nach Schaltjahr-Geburtstag',
      () {
        // Geburtstag: 29. Februar 2000 (Schaltjahr)
        final geburtstag = DateTime(2000, 2, 29);
        // Referenzdatum: 1. März 2023 (jetzt 23)
        final referenzdatum = DateTime(2023, 3, 1);

        final alter = getAlterAm(
          referenceDate: referenzdatum,
          date: geburtstag,
        );

        expect(alter.floor(), equals(23));
      },
    );

    test('berechnet das Alter korrekt über Jahreswechsel hinweg', () {
      // Geburtstag: 15. März 1995
      final geburtstag = DateTime(1995, 3, 15);
      // Referenzdatum: 1. Januar 2023 (noch 27, da Geburtstag noch nicht war)
      final referenzdatum = DateTime(2023, 1, 1);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(27));
    });

    test('berechnet das Alter korrekt für sehr junge Person', () {
      // Geburtstag: 1. Januar 2022
      final geburtstag = DateTime(2022, 1, 1);
      // Referenzdatum: 1. Juli 2022 (6 Monate alt)
      final referenzdatum = DateTime(2022, 7, 1);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(0));
      expect(alter, greaterThan(0.4)); // etwa 6 Monate
      expect(alter, lessThan(0.6));
    });

    test('berechnet das Alter korrekt für Baby am ersten Geburtstag', () {
      // Geburtstag: 1. Januar 2022
      final geburtstag = DateTime(2022, 1, 1);
      // Referenzdatum: 1. Januar 2023 (genau 1 Jahr alt)
      final referenzdatum = DateTime(2023, 1, 1);

      final alter = getAlterAm(referenceDate: referenzdatum, date: geburtstag);

      expect(alter.floor(), equals(1));
      expect(alter, greaterThanOrEqualTo(1.0));
      expect(alter, lessThan(1.1));
    });

    test('verwendet DateTime.now() wenn kein Referenzdatum angegeben', () {
      // Geburtstag vor langer Zeit
      final geburtstag = DateTime(1990, 1, 1);

      final alter = getAlterAm(date: geburtstag);

      // Sollte ein realistisches Alter sein (nicht negativ oder zu groß)
      expect(alter, greaterThan(30));
      expect(alter, lessThan(50)); // Stand 2025
    });

    test(
      'berechnet korrekt bei Geburtstag genau heute (basierend auf aktuellem Datum)',
      () {
        final heute = DateTime.now();
        final geburtstagVor25Jahren = DateTime(
          heute.year - 25,
          heute.month,
          heute.day,
        );

        final alter = getAlterAm(date: geburtstagVor25Jahren);

        expect(alter.floor(), equals(25));
        expect(alter, greaterThanOrEqualTo(25.0));
        expect(
          alter,
          lessThan(25.1),
        ); // sehr nah an 25.0, da heute Geburtstag ist
      },
    );
  });
}
