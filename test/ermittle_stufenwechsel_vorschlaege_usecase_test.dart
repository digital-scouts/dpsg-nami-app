import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufenwechsel/ermittle_stufenwechsel_vorschlaege_usecase.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  const useCase = ErmittleStufenwechselVorschlaegeUseCase();

  test(
    'ermittelt faellige und ueberfaellige Wechsel aus echten Mitgliedern',
    () {
      final sections = useCase(
        mitglieder: [
          _mitglied(
            id: 'w1',
            vorname: 'Emma',
            nachname: 'Mueller',
            geburtsdatum: DateTime(2017, 7, 1),
            stufe: Stufe.woelfling,
          ),
          _mitglied(
            id: 'w2',
            vorname: 'Anna',
            nachname: 'Alt',
            geburtsdatum: DateTime(2014, 1, 1),
            stufe: Stufe.woelfling,
          ),
        ],
        stichtag: DateTime(2026, 9, 1),
        altersgrenzen: StufenDefaults.build(),
      );

      final woelflinge = sections.firstWhere(
        (section) => section.stageFrom == Stufe.woelfling,
      );

      expect(woelflinge.stageTo, Stufe.jungpfadfinder);
      expect(
        woelflinge.vorschlaege.map(
          (vorschlag) => vorschlag.mitglied.mitgliedsnummer,
        ),
        ['w2', 'w1'],
      );
      expect(woelflinge.vorschlaege.first.istUeberfaellig, isTrue);
      expect(woelflinge.vorschlaege.last.istUeberfaellig, isFalse);
    },
  );

  test(
    'ignoriert zu junge Mitglieder, Rover und geplante Zielstufenrollen',
    () {
      final sections = useCase(
        mitglieder: [
          _mitglied(
            id: 'young',
            vorname: 'Leo',
            nachname: 'Jung',
            geburtsdatum: DateTime(2020, 6, 1),
            stufe: Stufe.woelfling,
          ),
          _mitglied(
            id: 'rover',
            vorname: 'Tim',
            nachname: 'Koch',
            geburtsdatum: DateTime(2004, 1, 1),
            stufe: Stufe.rover,
          ),
          _mitglied(
            id: 'planned',
            vorname: 'Mia',
            nachname: 'Geplant',
            geburtsdatum: DateTime(2017, 1, 1),
            stufe: Stufe.woelfling,
            extraRoles: [
              roleFromLegacy(
                stufe: Stufe.jungpfadfinder,
                art: RoleCategory.mitglied,
                start: DateTime(2026, 10, 1),
              ),
            ],
          ),
        ],
        stichtag: DateTime(2026, 9, 1),
        altersgrenzen: StufenDefaults.build(),
      );

      expect(sections.expand((section) => section.vorschlaege), isEmpty);
    },
  );

  test('ignoriert Mitglieder ohne bekanntes Geburtsdatum', () {
    final sections = useCase(
      mitglieder: [
        _mitglied(
          id: 'placeholder',
          vorname: 'Pia',
          nachname: 'Placeholder',
          geburtsdatum: Mitglied.peoplePlaceholderDate,
          stufe: Stufe.woelfling,
        ),
      ],
      stichtag: DateTime(2026, 9, 1),
      altersgrenzen: StufenDefaults.build(),
    );

    expect(sections.expand((section) => section.vorschlaege), isEmpty);
  });
}

Mitglied _mitglied({
  required String id,
  required String vorname,
  required String nachname,
  required DateTime geburtsdatum,
  required Stufe stufe,
  List<Role> extraRoles = const <Role>[],
}) {
  return Mitglied(
    vorname: vorname,
    nachname: nachname,
    geburtsdatum: geburtsdatum,
    eintrittsdatum: DateTime(2023, 9, 1),
    mitgliedsnummer: id,
    roles: [
      roleFromLegacy(
        stufe: stufe,
        art: RoleCategory.mitglied,
        start: DateTime(2023, 9, 1),
      ),
      ...extraRoles,
    ],
  );
}
