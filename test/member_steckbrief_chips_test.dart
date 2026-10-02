import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/member_detail/member_steckbrief_kopf.dart';

void main() {
  final heute = DateTime(2026, 10, 2);

  Mitglied mitRollen(List<Role> rollen) => Mitglied(
    mitgliedsnummer: '1',
    vorname: 'Mia',
    nachname: 'Test',
    geburtsdatum: DateTime(2000, 1, 1),
    eintrittsdatum: DateTime(2010, 1, 1),
    roles: rollen,
  );

  test('zeigt parallele Stufen und Leitungen ohne Doppelungen', () {
    final chips = steckbriefChips(
      mitRollen(<Role>[
        Role(type: 'Group::StammGruppeJungpfadfinder::Mitglied'),
        Role(type: 'Group::StammGruppePfadfinder::Mitglied'),
        Role(type: 'Group::StammGruppeRover::Leitung'),
        Role(type: 'Group::StammGruppeWoelflinge::Leitung'),
        Role(type: 'Group::StammGruppeWoelflinge::Leitung'),
      ]),
      heute: heute,
    );

    expect(chips, const <SteckbriefChip>[
      SteckbriefChip.stufe(Stufe.rover, leitung: true),
      SteckbriefChip.stufe(Stufe.woelfling, leitung: true),
      SteckbriefChip.stufe(Stufe.pfadfinder, leitung: false),
      SteckbriefChip.stufe(Stufe.jungpfadfinder, leitung: false),
    ]);
  });

  test('zeigt Sonstige, wenn nur Aemter ohne Stufe aktiv sind', () {
    final chips = steckbriefChips(
      mitRollen(<Role>[Role(label: 'Kassenprüfer*in')]),
      heute: heute,
    );

    expect(chips, const <SteckbriefChip>[SteckbriefChip.sonstige()]);
  });

  test('ignoriert Beitragsrollen, zukuenftige und beendete Rollen', () {
    final chips = steckbriefChips(
      mitRollen(<Role>[
        Role(type: 'Group::Mitglieder::OrdentlicheMitgliedschaft'),
        Role(
          type: 'Group::StammGruppeRover::Mitglied',
          startOn: DateTime(2027, 1, 1),
        ),
        Role(
          type: 'Group::StammGruppePfadfinder::Mitglied',
          startOn: DateTime(2020, 1, 1),
          endOn: DateTime(2024, 1, 1),
        ),
      ]),
      heute: heute,
    );

    expect(chips, isEmpty);
  });
}
