import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  test('priorisiert Rover vor Pfadfinder bei gleicher Leitungs-Art', () {
    final member = Mitglied(
      mitgliedsnummer: '4711',
      vorname: 'Lina',
      nachname: 'Beispiel',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      roles: <Role>[
        Role(
          type: 'Group::StammGruppePfadfinder::Leitung',
          startOn: DateTime(2025, 5, 1),
        ),
        Role(
          type: 'Group::StammGruppeRover::Leitung',
          startOn: DateTime(2024, 5, 1),
        ),
      ],
    );

    expect(MemberUtils.aktiveStufe(member), Stufe.rover);
  });
}
