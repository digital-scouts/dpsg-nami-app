import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/qualifikation/qualifikations_status.dart';

void main() {
  final heute = DateTime(2026, 9, 17);

  test('liefert fehlt, wenn kein Gueltig-bis-Datum vorhanden ist', () {
    expect(
      berechneStatus(gueltigBis: null, heute: heute),
      QualifikationsStatus.fehlt,
    );
  });

  test(
    'liefert fehlt, wenn das Gueltig-bis-Datum in der Vergangenheit liegt',
    () {
      expect(
        berechneStatus(gueltigBis: DateTime(2026, 9, 16), heute: heute),
        QualifikationsStatus.fehlt,
      );
    },
  );

  test(
    'liefert baldAblaufend, wenn das Gueltig-bis-Datum innerhalb der Warnschwelle liegt',
    () {
      expect(
        berechneStatus(
          gueltigBis: heute.add(const Duration(days: 90)),
          heute: heute,
        ),
        QualifikationsStatus.baldAblaufend,
      );
      expect(
        berechneStatus(
          gueltigBis: heute.add(const Duration(days: 1)),
          heute: heute,
        ),
        QualifikationsStatus.baldAblaufend,
      );
    },
  );

  test(
    'liefert gueltig, wenn das Gueltig-bis-Datum weit in der Zukunft liegt',
    () {
      expect(
        berechneStatus(
          gueltigBis: heute.add(const Duration(days: 91)),
          heute: heute,
        ),
        QualifikationsStatus.gueltig,
      );
    },
  );

  test('liefert baldAblaufend (nicht fehlt) genau am Ablauftag, '
      'einen Tag spaeter erst fehlt', () {
    expect(
      berechneStatus(gueltigBis: heute, heute: heute),
      QualifikationsStatus.baldAblaufend,
    );
    expect(
      berechneStatus(
        gueltigBis: heute,
        heute: heute.add(const Duration(days: 1)),
      ),
      QualifikationsStatus.fehlt,
    );
  });
}
