import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufenwechsel/naechster_stufenwechsel.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  final heute = DateTime(2026, 10, 2);
  final grenzen = StufenDefaults.build();

  Mitglied kind(int geburtsjahr, List<String> stufen, {DateTime? austritt}) =>
      Mitglied(
        mitgliedsnummer: '1',
        vorname: 'Kim',
        nachname: 'Test',
        geburtsdatum: DateTime(geburtsjahr, 2, 11),
        eintrittsdatum: DateTime(2020, 9, 1),
        austrittsdatum: austritt,
        roles: <Role>[
          for (final stufe in stufen)
            Role(
              type: 'Group::StammGruppe$stufe::Mitglied',
              startOn: DateTime(2024, 9, 1),
            ),
        ],
      );

  NaechsterStufenwechsel? wechsel(Mitglied m, {Altersgrenzen? mit}) =>
      berechneNaechstenStufenwechsel(
        m,
        altersgrenzen: mit ?? grenzen,
        stichtag: heute,
        heute: heute,
      );

  test('ab: Wechsel erst im genannten Jahr moeglich', () {
    final ergebnis = wechsel(kind(2018, ['Woelflinge']))!;
    expect(ergebnis.zeitpunkt, StufenwechselZeitpunkt.ab);
    expect(ergebnis.jahr, 2027);
    expect(ergebnis.zielStufe, Stufe.jungpfadfinder);
  });

  test('bis: Wechsel jetzt moeglich, spaetestens im genannten Jahr', () {
    final ergebnis = wechsel(kind(2014, ['Jungpfadfinder']))!;
    expect(ergebnis.zeitpunkt, StufenwechselZeitpunkt.bis);
    expect(ergebnis.jahr, 2027);
  });

  test('jetzt: Hoechstalter der aktuellen Stufe ueberschritten', () {
    final ergebnis = wechsel(kind(2011, ['Jungpfadfinder']))!;
    expect(ergebnis.zeitpunkt, StufenwechselZeitpunkt.jetzt);
  });

  test('parallele Stufen zaehlen ab der hoechsten aktiven Stufe', () {
    final ergebnis = wechsel(kind(2013, ['Jungpfadfinder', 'Pfadfinder']))!;
    expect(ergebnis.aktuelleStufe, Stufe.pfadfinder);
    expect(ergebnis.zielStufe, Stufe.rover);
    expect(ergebnis.zeitpunkt, StufenwechselZeitpunkt.ab);
    expect(ergebnis.jahr, 2028);
  });

  test('Rover sehen das Ende der Roverzeit', () {
    final bis = wechsel(kind(2006, ['Rover']))!;
    expect(bis.istEndeRoverzeit, isTrue);
    expect(bis.zeitpunkt, StufenwechselZeitpunkt.bis);
    expect(bis.jahr, 2026);
    expect(
      wechsel(kind(2004, ['Rover']))!.zeitpunkt,
      StufenwechselZeitpunkt.jetzt,
    );
  });

  test('beruecksichtigt eingestellte Altersgrenzen', () {
    final angepasst = grenzen.copyWithFor(
      Stufe.jungpfadfinder,
      const AltersIntervall(minJahre: 8, maxJahre: 13),
    );
    final ergebnis = wechsel(kind(2018, ['Woelflinge']), mit: angepasst)!;
    expect(ergebnis.zeitpunkt, StufenwechselZeitpunkt.bis);
  });

  test(
    'ohne Geburtsdatum, ohne Mitgliedsrolle oder ausgetreten kein Wechsel',
    () {
      expect(
        wechsel(
          kind(2018, [
            'Woelflinge',
          ]).copyWith(geburtsdatum: Mitglied.peoplePlaceholderDate),
        ),
        isNull,
      );
      expect(wechsel(kind(2018, const [])), isNull);
      expect(
        wechsel(kind(2018, ['Woelflinge'], austritt: DateTime(2026, 1, 1))),
        isNull,
      );
    },
  );
}
