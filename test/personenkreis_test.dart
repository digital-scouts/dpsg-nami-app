import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/personenkreis.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

import 'support/qualifikationen_testdaten.dart';

void main() {
  final heute = qualiHeute;

  PersonenkreisRegel regel(
    PersonenkreisRegelTyp typ,
    String wert, [
    RegelVerknuepfung verknuepfung = RegelVerknuepfung.oder,
  ]) => PersonenkreisRegel(typ: typ, wert: wert, verknuepfung: verknuepfung);

  test(
    'Leitung oder Amt: Mitglied allein und Mitgliederrollen zaehlen nicht',
    () {
      const kreis = Personenkreis.leitungOderAmt;

      expect(
        kreis.enthaelt(qualiMitglied('1', 1, [leitung('Rover')]), heute: heute),
        isTrue,
      );
      expect(
        kreis.enthaelt(
          qualiMitglied('2', 2, [amt('Kassenwart')]),
          heute: heute,
        ),
        isTrue,
      );
      expect(
        kreis.enthaelt(
          qualiMitglied('3', 3, [mitgliedRolle('Rover')]),
          heute: heute,
        ),
        isFalse,
      );
      expect(
        kreis.enthaelt(
          qualiMitglied('4', 4, [
            Role(type: 'Group::Mitglieder::OrdentlicheMitgliedschaft'),
          ]),
          heute: heute,
        ),
        isFalse,
      );
    },
  );

  test('beendete Rollen zaehlen nicht', () {
    final mitglied = qualiMitglied('1', 1, [
      Role(
        type: 'Group::StammGruppeRover::Leiter',
        startOn: DateTime(2020, 1, 1),
        endOn: DateTime(2025, 1, 1),
      ),
    ]);

    expect(Personenkreis.leitung.enthaelt(mitglied, heute: heute), isFalse);
  });

  test('und bindet staerker als oder', () {
    // Leitung und ab 18, oder Stufe Rover.
    final kreis = Personenkreis([
      regel(PersonenkreisRegelTyp.rollenart, 'leitung'),
      regel(PersonenkreisRegelTyp.alterAb, '18', RegelVerknuepfung.und),
      regel(PersonenkreisRegelTyp.stufe, 'rover'),
    ]);
    final jungeLeitung = qualiMitglied('1', 1, [
      leitung('Woelflinge'),
    ], geburtsdatum: DateTime(2010, 1, 1));
    final erwachseneLeitung = qualiMitglied('2', 2, [
      leitung('Woelflinge'),
    ], geburtsdatum: DateTime(1990, 1, 1));
    final junger = qualiMitglied('3', 3, [
      mitgliedRolle('Rover'),
    ], geburtsdatum: DateTime(2009, 1, 1));

    expect(kreis.enthaelt(jungeLeitung, heute: heute), isFalse);
    expect(kreis.enthaelt(erwachseneLeitung, heute: heute), isTrue);
    expect(kreis.enthaelt(junger, heute: heute), isTrue);
  });

  test('Altersregel greift ohne bekanntes Geburtsdatum nicht', () {
    final kreis = Personenkreis([regel(PersonenkreisRegelTyp.alterAb, '16')]);
    final ohneGeburtsdatum = qualiMitglied('1', 1, [
      leitung('Rover'),
    ], geburtsdatum: Mitglied.peoplePlaceholderDate);

    expect(kreis.enthaelt(ohneGeburtsdatum, heute: heute), isFalse);
  });

  test('Rollentyp vergleicht den Typ der Rolle', () {
    final kreis = Personenkreis([
      regel(PersonenkreisRegelTyp.rollentyp, 'Group::Stamm::Kurat'),
    ]);

    expect(
      kreis.enthaelt(qualiMitglied('1', 1, [amt('Kurat')]), heute: heute),
      isTrue,
    );
    expect(
      kreis.enthaelt(qualiMitglied('2', 2, [amt('Kassenwart')]), heute: heute),
      isFalse,
    );
  });

  test('JSON-Rundlauf und unbekannte Werte', () {
    final kreis = Personenkreis([
      regel(PersonenkreisRegelTyp.stufe, 'woelfling'),
      regel(PersonenkreisRegelTyp.alterBis, '20', RegelVerknuepfung.und),
    ]);

    expect(Personenkreis.fromJson(kreis.toJson()), kreis);
    expect(
      Personenkreis.fromJson([
        {'typ': 'gibtsnicht', 'wert': 'x'},
      ])!.regeln,
      isEmpty,
    );
  });
}
