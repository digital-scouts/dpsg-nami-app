import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/qualifikation/berechne_efz_gueltigkeit_usecase.dart';

void main() {
  const useCase = BerechneEfzGueltigkeitUseCase();

  test('liefert kein Gueltigkeitsdatum ohne Einsichtnahmen', () {
    final result = useCase(const <EfzEinsichtnahme>[]);
    expect(result.issuedOn, isNull);
    expect(result.gueltigBis, isNull);
  });

  test('ignoriert Eintraege ohne Ausstellungsdatum', () {
    final result = useCase(const <EfzEinsichtnahme>[
      EfzEinsichtnahme(id: 1, personId: 1),
    ]);
    expect(result.issuedOn, isNull);
    expect(result.gueltigBis, isNull);
  });

  test('berechnet Gueltig-bis als Ausstellungsdatum plus 5 Jahre', () {
    final result = useCase(<EfzEinsichtnahme>[
      EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2021, 3, 15)),
    ]);
    expect(result.issuedOn, DateTime(2021, 3, 15));
    expect(result.gueltigBis, DateTime(2026, 3, 15));
  });

  test('waehlt bei mehreren Einsichtnahmen das neueste Ausstellungsdatum', () {
    final result = useCase(<EfzEinsichtnahme>[
      EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2018, 1, 1)),
      EfzEinsichtnahme(id: 2, personId: 1, issuedOn: DateTime(2022, 6, 1)),
      EfzEinsichtnahme(id: 3, personId: 1, issuedOn: DateTime(2020, 1, 1)),
    ]);
    expect(result.issuedOn, DateTime(2022, 6, 1));
    expect(result.gueltigBis, DateTime(2027, 6, 1));
  });

  test('rollt ein Ausstellungsdatum vom 29. Februar in ein Nicht-Schaltjahr '
      'auf den 1. Maerz weiter', () {
    final result = useCase(<EfzEinsichtnahme>[
      EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2020, 2, 29)),
    ]);
    expect(result.issuedOn, DateTime(2020, 2, 29));
    expect(result.gueltigBis, DateTime(2025, 3, 1));
  });
}
