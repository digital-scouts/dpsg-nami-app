import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_status.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

void main() {
  const useCase = ErmittleQualifikationsUebersichtUseCase();
  final heute = DateTime(2026, 9, 17);

  final arbeitskontext = Arbeitskontext(
    aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
    verfuegbareLayer: const <ArbeitskontextLayer>[],
  );

  Mitglied mitglied(
    String nummer,
    String vorname,
    int personId,
    List<Role> roles,
  ) {
    return Mitglied(
      vorname: vorname,
      nachname: 'Beispiel',
      mitgliedsnummer: nummer,
      geburtsdatum: DateTime(2000, 1, 1),
      eintrittsdatum: DateTime(2010, 1, 1),
      personId: personId,
      roles: roles,
    );
  }

  ArbeitskontextReadModel buildReadModel() {
    return ArbeitskontextReadModel(
      arbeitskontext: arbeitskontext,
      mitglieder: <Mitglied>[
        // Anna (A): Woelflings-Leitung, gueltige Einsichtnahme.
        mitglied('A', 'Anna', 10, [
          Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
        ]),
        // Bea (B): Woelflings-Leitung, keine Einsichtnahme.
        mitglied('B', 'Bea', 20, [
          Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
        ]),
        // Carla (C): Woelflings-Leitung, abgelaufene Einsichtnahme.
        mitglied('C', 'Carla', 30, [
          Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
        ]),
        // Dana (D): nur Rover-Mitglied -> darf nicht erscheinen.
        mitglied('D', 'Dana', 40, [
          Role(type: 'Group::StammGruppeRover::Mitglied'),
        ]),
        // Erik (E): Rover-Mitglied UND Woelflings-Leitung -> muss erscheinen.
        mitglied('E', 'Erik', 50, [
          Role(type: 'Group::StammGruppeRover::Mitglied'),
          Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
        ]),
        // Frida (F): sonstige Funktion ohne Leitungs-Schluesselwort.
        mitglied('F', 'Frida', 60, [
          Role(type: 'Group::Stamm::Zuschussbeauftragter'),
        ]),
      ],
    );
  }

  test('zeigt bei einer Pflicht-Qualifikationsart alle Personen mit '
      'Funktionsrollen an, auch ohne vorhandenen Eintrag', () {
    final readModel = buildReadModel();
    final einsichtnahmen = <EfzEinsichtnahme>[
      // Anna (A): gueltig, Ausstellung vor 1 Jahr -> gueltig bis in 4 Jahren.
      EfzEinsichtnahme(
        id: 1,
        personId: 10,
        issuedOn: DateTime(heute.year - 1, heute.month, heute.day),
      ),
      // Carla (C): abgelaufen, Ausstellung vor 6 Jahren -> gueltig bis vor 1 Jahr.
      EfzEinsichtnahme(
        id: 2,
        personId: 30,
        issuedOn: DateTime(heute.year - 6, heute.month, heute.day),
      ),
      // Bea (B), Erik (E), Frida (F): keine Einsichtnahme vorhanden.
    ];

    final eintraege = useCase(
      readModel: readModel,
      einsichtnahmen: einsichtnahmen,
      heute: heute,
    );

    final mitgliedsnummern = eintraege
        .map((eintrag) => eintrag.mitglied.mitgliedsnummer)
        .toList();

    // Dana (D), rein Rover-Mitglied, darf nicht erscheinen.
    expect(mitgliedsnummern, isNot(contains('D')));
    // Alle anderen (inkl. Erik mit Doppelrolle und Frida als sonstige
    // Funktion) muessen erscheinen.
    expect(mitgliedsnummern.toSet(), {'A', 'B', 'C', 'E', 'F'});

    final byNummer = {
      for (final eintrag in eintraege)
        eintrag.mitglied.mitgliedsnummer: eintrag,
    };
    expect(byNummer['A']!.status, QualifikationsStatus.gueltig);
    expect(byNummer['B']!.status, QualifikationsStatus.fehlt);
    expect(byNummer['B']!.gueltigBis, isNull);
    expect(byNummer['C']!.status, QualifikationsStatus.fehlt);
    expect(byNummer['C']!.gueltigBis, isNotNull);
    expect(byNummer['E']!.status, QualifikationsStatus.fehlt);
    expect(byNummer['F']!.status, QualifikationsStatus.fehlt);

    // Sortierung: Personen ohne gueltigen Nachweis vor Anna (gueltig).
    expect(mitgliedsnummern.last, 'A');
  });
}
