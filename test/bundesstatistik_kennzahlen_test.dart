import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/bundesstatistik/baue_stammes_kennzahlen_usecase.dart';
import 'package:nami/domain/bundesstatistik/ermittle_stammes_hierarchie_usecase.dart';
import 'package:nami/domain/bundesstatistik/stammes_snapshot.dart';
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';
import 'package:nami/domain/member/mitglied.dart';

Mitglied _mitglied(String nummer, {String? gender, DateTime? geburtsdatum}) {
  return Mitglied(
    mitgliedsnummer: nummer,
    vorname: 'Vorname $nummer',
    nachname: 'Nachname',
    geburtsdatum: geburtsdatum ?? Mitglied.peoplePlaceholderDate,
    eintrittsdatum: DateTime(2020, 1, 1),
    gender: gender,
  );
}

ArbeitskontextReadModel _stammReadModel({
  String? layerTyp = 'Group::Stamm',
  Iterable<ArbeitskontextLayer> verfuegbareLayer = const [],
  int? parentLayerId,
  List<ArbeitskontextGruppe>? gruppen,
}) {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: ArbeitskontextLayer(
        id: 11,
        name: 'Stamm Test',
        layerTyp: layerTyp,
        parentLayerId: parentLayerId,
      ),
      verfuegbareLayer: verfuegbareLayer,
    ),
    rolesSindGeladen: true,
    mitglieder: <Mitglied>[
      _mitglied('1', gender: 'w'),
      _mitglied('2', gender: 'm'),
      _mitglied('3'),
      _mitglied('4', gender: 'w', geburtsdatum: DateTime(2006, 6, 15)),
      _mitglied('5', gender: 'm', geburtsdatum: DateTime(1990, 1, 1)),
      _mitglied('6', gender: 'd'),
      _mitglied('7'),
    ],
    gruppen:
        gruppen ??
        const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Meute',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeWoelflinge',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Runde',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeRover',
          ),
          ArbeitskontextGruppe(
            id: 23,
            name: 'Mitglieder',
            layerId: 11,
            gruppenTyp: 'Group::Mitglieder',
          ),
        ],
    mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '1',
        gruppenId: 21,
        rollenLabel: 'Mitglied',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '2',
        gruppenId: 21,
        rollenLabel: 'Mitglied',
      ),
      // Doppelte Rolle in derselben Stufe zaehlt einmal.
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '2',
        gruppenId: 21,
        rollenLabel: 'Mitglied',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '3',
        gruppenId: 22,
        rollenLabel: 'Mitglied',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '4',
        gruppenId: 21,
        rollenLabel: 'Leitung',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '5',
        gruppenId: 22,
        rollenLabel: 'Leiter',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '5',
        gruppenId: 21,
        rollenLabel: 'Hilfsleiter',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '1',
        gruppenId: 23,
        rollenTyp: 'Group::Mitglieder::OrdentlicheMitgliedschaft',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '2',
        gruppenId: 23,
        rollenTyp: 'Group::Mitglieder::OrdentlicheMitgliedschaft',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '6',
        gruppenId: 23,
        rollenTyp: 'Group::Mitglieder::Foerdermitgliedschaft',
      ),
    ],
  );
}

void main() {
  group('BaueStammesKennzahlenUseCase', () {
    const useCase = BaueStammesKennzahlenUseCase();
    final stichtag = DateTime(2026, 6, 15);

    test('zaehlt Mitglieder und Leitende je Stufe nach Geschlecht', () {
      final kennzahlen = useCase(_stammReadModel(), stichtag: stichtag);

      expect(
        kennzahlen.woelflinge,
        const GeschlechterVerteilung(
          gesamt: 2,
          maennlich: 1,
          weiblich: 1,
          divers: 0,
          geschlechtUnbekannt: 0,
        ),
      );
      expect(kennzahlen.rover.gesamt, 1);
      expect(kennzahlen.rover.geschlechtUnbekannt, 1);
      expect(kennzahlen.biber.gesamt, 0);
      expect(kennzahlen.leitendeWoelflinge.gesamt, 2);
      expect(kennzahlen.leitendeWoelflinge.weiblich, 1);
      expect(kennzahlen.leitendeWoelflinge.maennlich, 1);
      expect(kennzahlen.leitendeRover.gesamt, 1);
      expect(kennzahlen.istPlausibel, isTrue);
    });

    test('bildet Altersgruppen der Leitenden zum Stichtag', () {
      final kennzahlen = useCase(_stammReadModel(), stichtag: stichtag);

      // Mitglied 4 wird am Stichtag 20, Mitglied 5 ist 36.
      expect(kennzahlen.leitende.gesamt, 2);
      expect(kennzahlen.leitende.unter21, 1);
      expect(kennzahlen.leitende.von31Bis40, 1);
      expect(kennzahlen.leitende.von21Bis30, 0);
    });

    test('zaehlt ordentliche Mitgliedschaften und sonstige Mitglieder', () {
      final kennzahlen = useCase(_stammReadModel(), stichtag: stichtag);

      expect(kennzahlen.aktiveMitglieder, 2);
      // Mitglieder 6 und 7 haben keine Rolle in einer Stufengruppe.
      expect(kennzahlen.nichtLeitendeErwachsene, 2);
    });

    test('schaetzt nicht ableitbare Kennzahlen nicht', () {
      final json = useCase(_stammReadModel(), stichtag: stichtag).toJson();

      expect(json['passive_mitglieder'], isNull);
      expect(json['stammesvorstand'], isNull);
      expect(json['kuraten'], isNull);
      expect(json['aktive_mitglieder'], <String, Object?>{
        'gesamt': 2,
        'normaler_beitrag': null,
        'familienermaessigter_beitrag': null,
        'sozialermaessigter_beitrag': null,
      });
    });

    test(
      'meldet aktive Mitglieder als unbekannt ohne Mitgliedschaftsrollen',
      () {
        final readModel = ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(
            aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
          ),
          rolesSindGeladen: true,
          mitglieder: <Mitglied>[_mitglied('1')],
        );

        final kennzahlen = useCase(readModel, stichtag: stichtag);

        expect(kennzahlen.aktiveMitglieder, isNull);
        expect(kennzahlen.istPlausibel, isFalse);
      },
    );
  });

  group('BaueStammesKennzahlenUseCase bei Teilsicht', () {
    const useCase = BaueStammesKennzahlenUseCase();
    final stichtag = DateTime(2026, 6, 15);

    test('zaehlt nur lesbare Gruppen und laesst stammweite Werte leer', () {
      final kennzahlen = useCase(
        _stammReadModel(),
        stichtag: stichtag,
        abdeckung: StatistikAbdeckung.gruppen({21}),
      );

      expect(kennzahlen.abdeckung.istStamm, isFalse);
      expect(kennzahlen.aktiveMitglieder, isNull);
      expect(kennzahlen.nichtLeitendeErwachsene, isNull);
      expect(kennzahlen.leitende.gesamt, isNull);
      // Die Meute ist ganz lesbar, die Runde nicht.
      expect(kennzahlen.woelflinge.gesamt, 2);
      expect(kennzahlen.rover, const GeschlechterVerteilung.unbekannt());
      expect(kennzahlen.leitendeRover.gesamt, isNull);
      // Biber hat keine Gruppe und ist damit vollstaendig bekannt: 0.
      expect(kennzahlen.biber.gesamt, 0);
      expect(kennzahlen.gruppen.map((g) => (g.gruppenId, g.abgedeckt)), [
        (21, true),
        (22, false),
      ]);
      expect(kennzahlen.gruppen.last.mitglieder, isNull);
      expect(kennzahlen.istPlausibel, isTrue);
    });

    test('ist ohne lesbare Gruppe nicht plausibel', () {
      final kennzahlen = useCase(
        _stammReadModel(),
        stichtag: stichtag,
        abdeckung: StatistikAbdeckung.gruppen(const <int>{}),
      );

      expect(kennzahlen.istPlausibel, isFalse);
      expect(kennzahlen.gruppen.every((g) => !g.abgedeckt), isTrue);
    });

    test(
      'meldet eine Gruppe ohne gelieferte Rollen als unbekannt, nicht 0',
      () {
        // group_read auf die Meute, Hitobito liefert aber keine fremden Rollen.
        final kennzahlen = useCase(
          _stammReadModel(),
          stichtag: stichtag,
          abdeckung: StatistikAbdeckung.gruppen(
            const <int>{},
            gruppenOhneRollen: {21},
          ),
        );

        final meute = kennzahlen.gruppen.firstWhere((g) => g.gruppenId == 21);
        expect(meute.abgedeckt, isFalse);
        expect(meute.mitglieder, isNull);
        expect(kennzahlen.woelflinge, const GeschlechterVerteilung.unbekannt());
        expect(kennzahlen.istPlausibel, isFalse);
      },
    );

    test('liefert bei voller Sicht alle Stufengruppen mit Zaehlern', () {
      final kennzahlen = useCase(_stammReadModel(), stichtag: stichtag);

      expect(kennzahlen.gruppen, hasLength(2));
      expect(kennzahlen.gruppen.first.mitglieder?.gesamt, 2);
      expect(kennzahlen.gruppen.first.leitende?.gesamt, 2);
      expect(kennzahlen.gruppen.last.mitglieder?.gesamt, 1);
      expect(kennzahlen.gruppen.last.leitende?.gesamt, 1);
    });
  });

  group('ErmittleStammesHierarchieUseCase', () {
    const useCase = ErmittleStammesHierarchieUseCase();

    test('erkennt einen Stamm am Layer-Typ', () {
      final hierarchie = useCase(_stammReadModel());

      expect(hierarchie?.stammId, '11');
      expect(hierarchie?.bezirkId, isNull);
      expect(hierarchie?.dvId, isNull);
    });

    test('lehnt andere Layer-Typen ab', () {
      expect(useCase(_stammReadModel(layerTyp: 'Group::Bezirk')), isNull);
    });

    test('erkennt einen Stamm ohne Layer-Typ an den Stufengruppen', () {
      expect(useCase(_stammReadModel(layerTyp: null))?.stammId, '11');
      expect(
        useCase(
          _stammReadModel(
            layerTyp: null,
            gruppen: const <ArbeitskontextGruppe>[
              ArbeitskontextGruppe(
                id: 23,
                name: 'X',
                layerId: 11,
                gruppenTyp: 'Group::Mitglieder',
              ),
            ],
          ),
        ),
        isNull,
      );
    });

    test('ermittelt Bezirk und Dioezese aus bekannten Eltern-Layern', () {
      final hierarchie = useCase(
        _stammReadModel(
          parentLayerId: 20,
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(
              id: 20,
              name: 'Bezirk',
              parentLayerId: 30,
              layerTyp: 'Group::Bezirk',
            ),
            ArbeitskontextLayer(
              id: 30,
              name: 'DV',
              parentLayerId: 40,
              layerTyp: 'Group::Dioezese',
            ),
            ArbeitskontextLayer(id: 40, name: 'Bund', layerTyp: 'Group::Bund'),
          ],
        ),
      );

      expect(hierarchie?.bezirkId, '20');
      expect(hierarchie?.dvId, '30');
    });

    test('laesst unbekannte Ebenen leer statt zu raten', () {
      final hierarchie = useCase(
        _stammReadModel(
          parentLayerId: 20,
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 20, name: 'Unbekannt', parentLayerId: 30),
          ],
        ),
      );

      expect(hierarchie?.bezirkId, isNull);
      expect(hierarchie?.dvId, isNull);
    });
  });

  group('StammesSnapshot', () {
    test('sendet Zeitstempel hoechstens mit Millisekunden', () {
      final snapshot = StammesSnapshot(
        stammId: '11',
        senderId: 'install-1',
        sentAt: DateTime.utc(2026, 6, 15, 10, 0, 0, 123, 456),
        sourceDataAsOf: DateTime.utc(2026, 6, 15, 9, 0, 0, 0, 999),
        kennzahlen: const BaueStammesKennzahlenUseCase()(
          _stammReadModel(),
          stichtag: DateTime(2026, 6, 15),
        ),
      );

      final json = snapshot.toJson();

      // Den Sendezeitpunkt bestimmt der Server selbst (received_at).
      expect(json.containsKey('sent_at'), isFalse);
      expect(json['source_data_as_of'], '2026-06-15T09:00:00.000Z');
    });

    test('serialisiert nach Schema 2026-10-08 und liest sich zurueck', () {
      const useCase = BaueStammesKennzahlenUseCase();
      final kennzahlen = useCase(
        _stammReadModel(),
        stichtag: DateTime(2026, 6, 15),
      );
      final snapshot = StammesSnapshot(
        stammId: '11',
        dvId: '30',
        senderId: 'install-1',
        sentAt: DateTime.utc(2026, 6, 15, 10),
        sourceDataAsOf: DateTime.utc(2026, 6, 15, 9, 30),
        kennzahlen: kennzahlen,
      );

      final json = snapshot.toJson();

      expect(json['schema_version'], '2026-10-08');
      expect(json['stamm_id'], '11');
      expect(json['bezirk_id'], isNull);
      expect(json['abdeckung'], 'stamm');
      expect((json['gruppen'] as List).map((g) => (g as Map)['gruppe_id']), [
        '21',
        '22',
      ]);
      expect((json['metrics'] as Map).containsKey('woelflinge'), isFalse);

      final restored = StammesSnapshot.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        sentAt: DateTime.utc(2026, 6, 15, 10),
      );
      expect(restored.kennzahlen, kennzahlen);
      expect(restored.sourceDataAsOf, DateTime.utc(2026, 6, 15, 9, 30));
      expect(restored.sentAt, DateTime.utc(2026, 6, 15, 10));
    });

    test('sendet bei Teilsicht keine stammweiten Werte', () {
      final kennzahlen = const BaueStammesKennzahlenUseCase()(
        _stammReadModel(),
        stichtag: DateTime(2026, 6, 15),
        abdeckung: StatistikAbdeckung.gruppen({21}),
      );
      final json = StammesSnapshot(
        stammId: '11',
        senderId: 'install-1',
        sentAt: DateTime.utc(2026, 6, 15, 10),
        sourceDataAsOf: DateTime.utc(2026, 6, 15, 9),
        kennzahlen: kennzahlen,
      ).toJson();

      expect(json['abdeckung'], 'gruppen');
      expect(json['metrics'], isNull);
      expect(json['gruppen'], [
        {
          'gruppe_id': '21',
          'stufe': 'woelflinge',
          'abgedeckt': true,
          'mitglieder': {
            'gesamt': 2,
            'maennlich': 1,
            'weiblich': 1,
            'divers': 0,
            'geschlecht_unbekannt': 0,
          },
          'leitende': {
            'gesamt': 2,
            'maennlich': 1,
            'weiblich': 1,
            'divers': 0,
            'geschlecht_unbekannt': 0,
          },
        },
        {'gruppe_id': '22', 'stufe': 'rover', 'abgedeckt': false},
      ]);

      final restored = StammesSnapshot.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored.kennzahlen.abdeckung, StatistikAbdeckung.gruppen({21}));
      expect(restored.kennzahlen.woelflinge.gesamt, 2);
      expect(restored.kennzahlen.rover.gesamt, isNull);
    });
  });
}
