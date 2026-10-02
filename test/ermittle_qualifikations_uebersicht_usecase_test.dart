import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/domain/qualifikation/qualifikations_status.dart';

import 'support/qualifikationen_testdaten.dart';

void main() {
  const useCase = ErmittleQualifikationsUebersichtUseCase();
  final heute = qualiHeute;

  final mitglieder = [
    // Anna: Woelflings-Leitung, gueltiges EFZ.
    qualiMitglied('A', 10, [leitung('Woelflinge')]),
    // Bea: Woelflings-Leitung, kein EFZ.
    qualiMitglied('B', 20, [leitung('Woelflinge')]),
    // Carla: Leitung, EFZ abgelaufen.
    qualiMitglied('C', 30, [leitung('Pfadfinder')]),
    // Dana: nur Rover-Mitglied, gehoert nicht zum Kreis.
    qualiMitglied('D', 40, [mitgliedRolle('Rover')]),
    // Frida: Amt ohne Leitungs-Schluesselwort, EFZ laeuft in 30 Tagen ab.
    qualiMitglied('F', 60, [amt('Zuschussbeauftragter')]),
  ];
  final efz = [
    EfzEinsichtnahme(id: 1, personId: 10, issuedOn: DateTime(2025, 1, 1)),
    EfzEinsichtnahme(id: 2, personId: 30, issuedOn: DateTime(2020, 1, 1)),
    EfzEinsichtnahme(id: 3, personId: 60, issuedOn: DateTime(2021, 11, 1)),
  ];

  test('EFZ: Leitung oder Amt, fehlt und abgelaufen zaehlen als fehlt', () {
    final zeilen = useCase(
      readModel: qualiReadModel(mitglieder: mitglieder, efz: efz),
      einstellungen: const QualifikationsEinstellungen(),
      heute: heute,
    );

    final efzZeile = zeilen.first;
    expect(efzZeile.art.istEfz, isTrue);
    expect(efzZeile.eintraege.map((e) => e.mitglied.mitgliedsnummer), <String>[
      'B',
      'C',
      'F',
      'A',
    ]);
    expect(efzZeile.benoetigt, 4);
    expect(efzZeile.fehlt, 2);
    expect(efzZeile.bald, 1);
    expect(efzZeile.erfuellt, 2);
    expect(efzZeile.eintraege[1].status, QualifikationsStatus.abgelaufen);
  });

  test('Warnschwelle folgt dem Erinnerungs-Vorlauf', () {
    final einstellungen = const QualifikationsEinstellungen().mitArt(
      QualifikationsSchluessel.efz,
      const ArtEinstellung(
        erinnerung: QualifikationsErinnerung(tageVorher: 10),
      ),
    );

    final efzZeile = useCase(
      readModel: qualiReadModel(mitglieder: mitglieder, efz: efz),
      einstellungen: einstellungen,
      heute: heute,
    ).first;

    expect(efzZeile.bald, 0);
    expect(efzZeile.gueltig, 2);
  });

  test('ohne EFZ-Berechtigung ist die EFZ-Zeile gesperrt', () {
    final efzZeile = useCase(
      readModel: qualiReadModel(
        mitglieder: mitglieder,
        efzStand: TeildatenStand.keineBerechtigung,
      ),
      einstellungen: const QualifikationsEinstellungen(),
      heute: heute,
    ).first;

    expect(efzZeile.gesperrt, isTrue);
    expect(efzZeile.eintraege, isEmpty);
  });

  test('Katalog: EFZ immer, Hitobito-Arten nur mit Inhabern, Vorgaben '
      'angezeigt, Rest ausgeblendet und alphabetisch', () {
    final readModel = qualiReadModel(
      mitglieder: mitglieder,
      qualifikationen: [
        quali(1, 10, woodbadgeId, 'Woodbadge'),
        quali(2, 10, ersteHilfeId, 'Erste-Hilfe-Kurs', gueltigkeitJahre: 2),
        quali(3, 20, praeventionId, 'Präventionsschulung'),
        quali(4, 20, 30, 'Modulausbildung'),
      ],
    );

    final katalog = useCase.katalog(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
    );

    expect(katalog.map((k) => k.art.label), <String>[
      'Erweitertes Führungszeugnis',
      'Präventionsschulung',
      'Erste-Hilfe-Kurs',
      'Modulausbildung',
      'Woodbadge',
    ]);
    expect(katalog.map((k) => k.angezeigt), <bool>[
      true,
      true,
      true,
      false,
      false,
    ]);
    expect(katalog[2].art.gueltigkeitJahre, 2);
  });

  test('Katalog folgt der gespeicherten Reihenfolge und Sichtbarkeit', () {
    final readModel = qualiReadModel(
      mitglieder: mitglieder,
      qualifikationen: [
        quali(1, 10, woodbadgeId, 'Woodbadge'),
        quali(3, 20, praeventionId, 'Präventionsschulung'),
      ],
    );
    final einstellungen =
        const QualifikationsEinstellungen(
              reihenfolge: <String>['hitobito:3', 'efz'],
            )
            .mitArt('hitobito:3', const ArtEinstellung(angezeigt: true))
            .mitArt('hitobito:14', const ArtEinstellung(angezeigt: false))
            // Gespeicherte Art, die im Kontext niemand hat, bleibt unsichtbar.
            .mitArt('hitobito:99', const ArtEinstellung(angezeigt: true));

    final zeilen = useCase(
      readModel: readModel,
      einstellungen: einstellungen,
      heute: heute,
    );

    expect(zeilen.map((z) => z.art.schluessel), <String>['hitobito:3', 'efz']);
  });

  test('Hitobito-Art: neueste zaehlt, ohne Ablauf ist gueltig', () {
    final readModel = qualiReadModel(
      mitglieder: mitglieder,
      qualifikationen: [
        // Anna: alte abgelaufen, neue gueltig.
        quali(
          1,
          10,
          praeventionId,
          'Präventionsschulung',
          finishAt: DateTime(2024, 1, 1),
        ),
        quali(
          2,
          10,
          praeventionId,
          'Präventionsschulung',
          finishAt: DateTime(2029, 1, 1),
        ),
        // Bea: abgelaufen, reaktivierbar.
        quali(
          3,
          20,
          praeventionId,
          'Präventionsschulung',
          finishAt: DateTime(2026, 9, 1),
          reaktivierbar: true,
        ),
        // Carla: ohne Ablauf.
        quali(4, 30, praeventionId, 'Präventionsschulung'),
      ],
    );

    final zeile = useCase(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      heute: heute,
    ).firstWhere((z) => z.art.hitobitoId == praeventionId);

    final nachNummer = {
      for (final e in zeile.eintraege) e.mitglied.mitgliedsnummer: e,
    };
    expect(nachNummer['A']!.status, QualifikationsStatus.gueltig);
    expect(nachNummer['A']!.gueltigBis, DateTime(2029, 1, 1));
    expect(nachNummer['B']!.status, QualifikationsStatus.abgelaufen);
    expect(nachNummer['B']!.reaktivierbar, isTrue);
    expect(nachNummer['C']!.ohneAblauf, isTrue);
    expect(nachNummer['C']!.status, QualifikationsStatus.gueltig);
    expect(nachNummer['F']!.status, QualifikationsStatus.fehlt);
    expect(zeile.fehlt, 2);
    expect(zeile.erfuellt, 2);
  });
}
