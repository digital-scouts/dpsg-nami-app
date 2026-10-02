import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/pfadfinder_verlauf.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  final heute = DateTime(2026, 10, 2);

  Mitglied mit(List<Role> rollen, {DateTime? eintritt, DateTime? austritt}) =>
      Mitglied(
        mitgliedsnummer: '1',
        vorname: 'Kim',
        nachname: 'Test',
        geburtsdatum: DateTime(1996, 3, 14),
        eintrittsdatum: eintritt ?? DateTime(2004, 4, 1),
        austrittsdatum: austritt,
        roles: rollen,
      );

  test('berechnet Leitungsjahre ohne Doppelzaehlung paralleler Leitungen', () {
    final verlauf = berechnePfadfinderVerlauf(
      mit(<Role>[
        Role(
          type: 'Group::StammGruppeWoelflinge::Mitglied',
          startOn: DateTime(2004, 4, 1),
          endOn: DateTime(2007, 8, 31),
        ),
        Role(
          type: 'Group::StammGruppeRover::Leitung',
          startOn: DateTime(2020, 1, 1),
        ),
        Role(
          type: 'Group::StammGruppeWoelflinge::Leitung',
          startOn: DateTime(2022, 1, 1),
        ),
        Role(label: 'Kassenprüfer*in', startOn: DateTime(2023, 1, 1)),
        Role(
          type: 'Group::StammGruppeJungpfadfinder::Leitung',
          startOn: DateTime(2027, 1, 1),
        ),
      ]),
      heute: heute,
    );

    expect(verlauf.segmente, hasLength(4));
    expect(verlauf.leitungsJahre, closeTo(6.75, 0.05));
    expect(verlauf.stufenAlsMitglied, {Stufe.woelfling});
    expect(verlauf.unbekanntBis, isNull);
    expect(verlauf.istNeu, isFalse);
  });

  test('markiert die Zeit vor der ersten bekannten Rolle', () {
    final verlauf = berechnePfadfinderVerlauf(
      mit(<Role>[
        Role(
          type: 'Group::StammGruppeRover::Leitung',
          startOn: DateTime(2022, 9, 1),
        ),
      ]),
      heute: heute,
    );

    expect(verlauf.von, DateTime(2004, 4, 1));
    expect(verlauf.unbekanntBis, DateTime(2022, 9, 1));
  });

  test('bricht nicht an krummen Daten', () {
    final verlauf = berechnePfadfinderVerlauf(
      mit(<Role>[
        // Ende vor Start
        Role(
          type: 'Group::StammGruppePfadfinder::Mitglied',
          startOn: DateTime(2020, 1, 1),
          endOn: DateTime(2019, 1, 1),
        ),
        // ohne Startdatum
        Role(type: 'Group::StammGruppeRover::Mitglied'),
        // vor dem Eintritt
        Role(
          type: 'Group::StammGruppeBiber::Mitglied',
          startOn: DateTime(2001, 1, 1),
          endOn: DateTime(2004, 1, 1),
        ),
      ]),
      heute: heute,
    );

    expect(verlauf.segmente, hasLength(2));
    expect(verlauf.von, DateTime(2001, 1, 1));
    expect(verlauf.segmente.last.von, DateTime(2004, 4, 1));
  });

  test('Neulinge und Personen ohne Rollen', () {
    final neu = berechnePfadfinderVerlauf(
      mit(<Role>[], eintritt: DateTime(2026, 9, 25)),
      heute: heute,
    );
    expect(neu.istNeu, isTrue);
    expect(neu.segmente, isEmpty);

    final ausgetreten = berechnePfadfinderVerlauf(
      mit(<Role>[], austritt: DateTime(2025, 12, 31)),
      heute: heute,
    );
    expect(ausgetreten.bis, DateTime(2025, 12, 31));
  });
}
