import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';

import 'support/qualifikationen_testdaten.dart';

void main() {
  const useCase = PlaneQualifikationsErinnerungenUseCase();
  // Freitag, 8 Uhr: der heutige Morgen um 9 Uhr ist noch erreichbar.
  final jetzt = DateTime(2026, 10, 2, 8);

  final mitglieder = [
    qualiMitglied('ICH', 1, [leitung('Rover')], fahrtenname: 'Funke'),
    qualiMitglied('B', 2, [leitung('Pfadfinder')]),
    qualiMitglied('C', 3, [amt('Kurat')]),
    qualiMitglied('D', 4, [leitung('Woelflinge')]),
  ];
  // EFZ: eigenes laeuft am 20.11.2026 ab (49 Tage), B und C am 01.03.2027,
  // D am 01.01.2030.
  final efz = [
    EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2021, 11, 20)),
    EfzEinsichtnahme(id: 2, personId: 2, issuedOn: DateTime(2022, 3, 1)),
    EfzEinsichtnahme(id: 3, personId: 3, issuedOn: DateTime(2022, 3, 1)),
    EfzEinsichtnahme(id: 4, personId: 4, issuedOn: DateTime(2025, 1, 1)),
  ];
  final readModel = qualiReadModel(mitglieder: mitglieder, efz: efz);

  test('fremde Ablaeufe gebuendelt je Tag, eigener einzeln am naechsten '
      'Morgen, wenn der Termin schon vorbei ist', () {
    final plan = useCase(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: 1,
      supporter: true,
      jetzt: jetzt,
    );

    // Eigenes EFZ, B und C gebuendelt, D erst 2029.
    expect(plan, hasLength(3));
    final eigene = plan.first;
    expect(eigene.eigene, isTrue);
    expect(eigene.zeitpunkt, DateTime(2026, 10, 2, 9));
    expect(eigene.gueltigBis, DateTime(2026, 11, 20));

    final fremde = plan[1];
    expect(fremde.eigene, isFalse);
    expect(fremde.zeitpunkt, DateTime(2026, 12, 1, 9));
    expect(fremde.personen, hasLength(2));
    expect(fremde.meldeSchluessel, hasLength(2));
    expect(plan.last.zeitpunkt, DateTime(2029, 10, 3, 9));
  });

  test(
    'ohne Supporter nur die eigene Erinnerung aus den Benachrichtigungen',
    () {
      final plan = useCase(
        readModel: readModel,
        einstellungen: const QualifikationsEinstellungen(),
        eigenePersonId: 1,
        supporter: false,
        jetzt: jetzt,
      );

      expect(plan.map((p) => p.eigene), <bool>[true]);
    },
  );

  test('eigene Ablaeufe kommen nicht doppelt, der laengere Vorlauf gilt', () {
    final einstellungen = const QualifikationsEinstellungen(
      eigene: EigeneQualifikationsErinnerung(tageVorher: 10),
    );

    final plan = useCase(
      readModel: readModel,
      einstellungen: einstellungen,
      eigenePersonId: 1,
      supporter: true,
      jetzt: jetzt,
    ).where((p) => p.eigene);

    expect(plan, hasLength(1));
    // 90 Tage aus der EFZ-Erinnerung sind schon vorbei: naechster Morgen.
    expect(plan.single.zeitpunkt, DateTime(2026, 10, 2, 9));
  });

  test('bereits gemeldete Ablaeufe werden nicht erneut geplant', () {
    final ersterPlan = useCase(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: 1,
      supporter: true,
      jetzt: jetzt,
    );
    final eigenerSchluessel = ersterPlan.first.meldeSchluessel.single;

    final plan = useCase(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: 1,
      supporter: true,
      jetzt: DateTime(2026, 10, 3, 8),
      bereitsGeplant: {eigenerSchluessel: DateTime(2026, 10, 2, 9)},
    );

    expect(plan.where((p) => p.eigene), isEmpty);
  });

  test('aus heisst keine Erinnerung, auch nicht fuer die eigene', () {
    final einstellungen =
        const QualifikationsEinstellungen(
          eigene: EigeneQualifikationsErinnerung(aktiv: false),
        ).mitArt(
          QualifikationsSchluessel.efz,
          const ArtEinstellung(
            erinnerung: QualifikationsErinnerung(aktiv: false),
          ),
        );

    final plan = useCase(
      readModel: readModel,
      einstellungen: einstellungen,
      eigenePersonId: 1,
      supporter: true,
      jetzt: jetzt,
    );

    expect(plan, isEmpty);
  });

  test('begrenzt auf die naechsten Mitteilungen', () {
    final viele = [
      for (var i = 0; i < 60; i++)
        qualiMitglied('M$i', 100 + i, [leitung('Rover')]),
    ];
    final vieleEfz = [
      for (var i = 0; i < 60; i++)
        EfzEinsichtnahme(
          id: 100 + i,
          personId: 100 + i,
          issuedOn: DateTime(2022, 1, 1).add(Duration(days: i)),
        ),
    ];

    final plan = useCase(
      readModel: qualiReadModel(mitglieder: viele, efz: vieleEfz),
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: null,
      supporter: true,
      jetzt: jetzt,
    );

    expect(
      plan,
      hasLength(PlaneQualifikationsErinnerungenUseCase.maxMitteilungen),
    );
    expect(plan.first.zeitpunkt.isBefore(plan.last.zeitpunkt), isTrue);
  });

  test('eigene Ablaeufe fuer die Meldung im Hub', () {
    final ablaeufe = useCase.eigeneAblaeufe(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: 1,
      heute: DateTime(2026, 10, 2),
    );

    expect(ablaeufe, hasLength(1));
    expect(ablaeufe.single.gueltigBis, DateTime(2026, 11, 20));
    expect(ablaeufe.single.abgelaufen, isFalse);
  });
}
