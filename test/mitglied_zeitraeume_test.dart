import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/mitglied_zeitraeume.dart';

void main() {
  Mitglied geborenAm(DateTime geburtsdatum) => Mitglied(
    mitgliedsnummer: '1',
    vorname: 'Mia',
    nachname: 'Test',
    geburtsdatum: geburtsdatum,
    eintrittsdatum: DateTime(2020, 1, 1),
  );

  final heute = DateTime(2026, 10, 2);

  test('liefert den naechsten Geburtstag mit Tagen und neuem Alter', () {
    final heuteGeburtstag = naechsterGeburtstag(
      geborenAm(DateTime(2018, 10, 2)),
      heute,
    )!;
    expect(heuteGeburtstag.tage, 0);
    expect(heuteGeburtstag.wirdAlter, 8);

    final schonVorbei = naechsterGeburtstag(
      geborenAm(DateTime(1996, 3, 14)),
      heute,
    )!;
    expect(schonVorbei.datum, DateTime(2027, 3, 14));
    expect(schonVorbei.wirdAlter, 31);
    expect(schonVorbei.tage, 163);
  });

  test('ohne bekanntes Geburtsdatum gibt es keinen Geburtstag', () {
    expect(
      naechsterGeburtstag(geborenAm(Mitglied.peoplePlaceholderDate), heute),
      isNull,
    );
  });

  test('ein 29. Februar faellt in Nicht-Schaltjahren auf den 1. Maerz', () {
    final geburtstag = naechsterGeburtstag(
      geborenAm(DateTime(2016, 2, 29)),
      heute,
    )!;
    expect(geburtstag.datum, DateTime(2027, 3, 1));
  });

  test('zaehlt ganze Kalendermonate', () {
    expect(monateZwischen(DateTime(2026, 9, 25), heute), 0);
    expect(monateZwischen(DateTime(2004, 4, 1), heute), 270);
    expect(monateZwischen(DateTime(2026, 3, 3), heute), 6);
    expect(monateZwischen(heute, DateTime(2026, 1, 1)), 0);
  });
}
