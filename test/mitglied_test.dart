import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';

void main() {
  test('akzeptiert leeren Vor- und Nachnamen als fehlende People-Felder', () {
    final mitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '1234',
      vorname: '',
      nachname: '',
    );

    expect(mitglied.vorname, isEmpty);
    expect(mitglied.nachname, isEmpty);
    expect(mitglied.fullName, isEmpty);
  });
}
