import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/ist_fuehrungszeugnispflichtig_usecase.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

void main() {
  const useCase = IstFuehrungszeugnispflichtigUseCase();

  Mitglied mitgliedMit(List<Role> roles) {
    return Mitglied(
      vorname: 'Test',
      nachname: 'Person',
      mitgliedsnummer: 'T1',
      geburtsdatum: DateTime(2000, 1, 1),
      eintrittsdatum: DateTime(2010, 1, 1),
      roles: roles,
    );
  }

  test('eine reine Rover-Mitgliedsrolle macht nicht pflichtig', () {
    final mitglied = mitgliedMit([
      Role(type: 'Group::StammGruppeRover::Mitglied'),
    ]);

    expect(useCase(mitglied), isFalse);
  });

  test('eine Woelflings-Leitungsrolle macht pflichtig', () {
    final mitglied = mitgliedMit([
      Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
    ]);

    expect(useCase(mitglied), isTrue);
  });

  test(
    'Woelflings-Leitung UND Rover-Mitgliedschaft zusammen machen pflichtig',
    () {
      final mitglied = mitgliedMit([
        Role(type: 'Group::StammGruppeWoelflinge::Leiter'),
        Role(type: 'Group::StammGruppeRover::Mitglied'),
      ]);

      expect(useCase(mitglied), isTrue);
    },
  );

  test('Stammesfuehrung macht pflichtig', () {
    final mitglied = mitgliedMit([Role(type: 'Group::Stamm::Stammesfuehrung')]);

    expect(useCase(mitglied), isTrue);
  });

  test(
    'eine sonstige Funktionsrolle (z.B. Zuschussbeauftragte*r) macht ebenfalls '
    'pflichtig, obwohl sie kein bekanntes Leitungs-Schluesselwort enthaelt',
    () {
      final mitglied = mitgliedMit([
        Role(type: 'Group::Stamm::Zuschussbeauftragter'),
      ]);

      expect(useCase(mitglied), isTrue);
    },
  );

  test('eine inaktive (beendete) Leitungsrolle macht nicht pflichtig', () {
    final mitglied = mitgliedMit([
      Role(
        type: 'Group::StammGruppeWoelflinge::Leiter',
        startOn: DateTime(2015, 1, 1),
        endOn: DateTime(2020, 1, 1),
      ),
    ]);

    expect(useCase(mitglied), isFalse);
  });

  test('eine Person ganz ohne Rollen ist nicht pflichtig', () {
    expect(useCase(mitgliedMit(const <Role>[])), isFalse);
  });
}
