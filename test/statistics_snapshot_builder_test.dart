import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/statistics/statistics_snapshot_builder.dart';

void main() {
  const builder = StatisticsSnapshotBuilder();

  test('zaehlt Hilfsleiter als Leitende und kein Sonstige-Bucket', () {
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Test'),
      ),
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Mara',
          nachname: 'Muster',
        ),
        Mitglied.peopleListItem(
          mitgliedsnummer: '2',
          vorname: 'Lena',
          nachname: 'Leiter',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 21,
          name: 'Meute Nord',
          layerId: 11,
          gruppenTyp: 'Group::StammGruppeWoelflinge',
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
          rollenLabel: 'Hilfsleiter',
        ),
      ],
    );

    final snapshot = builder.build(readModel);

    expect(snapshot.members, 1);
    expect(snapshot.leaders, 1);

    final distribution = snapshot.groupDistributions.single;
    expect(distribution.stufe, Stufe.woelfling);
    expect(distribution.mitgliedCount, 1);
    expect(distribution.leitungCount, 1);

    final detail = snapshot.detailById('21');
    expect(detail, isNotNull);
    expect(detail!.members, 1);
    expect(detail.leaders, 1);
  });

  test(
    'nutzt dynamischen Gruppenanzeigenamen und ignoriert unbekannten Typ',
    () {
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Test'),
        ),
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Tim',
            nachname: 'Test',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Interner Name',
            displayName: 'Display Meute',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeWoelflinge',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Unbekannt',
            layerId: 11,
            gruppenTyp: 'Group::Foobar',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Mitglied',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 22,
            rollenLabel: 'Mitglied',
          ),
        ],
      );

      final snapshot = builder.build(readModel);

      expect(snapshot.groups.length, 1);
      expect(snapshot.groups.single.name, 'Display Meute');
      expect(snapshot.detailById('22'), isNull);
    },
  );

  test('geschlecht basiert nur auf Mitgliedern', () {
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Test'),
      ),
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Mia',
          nachname: 'Mitglied',
          gender: 'w',
        ),
        Mitglied.peopleListItem(
          mitgliedsnummer: '2',
          vorname: 'Max',
          nachname: 'Leiter',
          gender: 'm',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 21,
          name: 'Meute Nord',
          layerId: 11,
          gruppenTyp: 'Group::StammGruppeWoelflinge',
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
          rollenLabel: 'Leiter',
        ),
      ],
    );

    final snapshot = builder.build(readModel);

    expect(snapshot.gender.length, 1);
    expect(snapshot.gender.single.label, 'Weiblich');
    expect(snapshot.gender.single.value, 1);
  });
}
