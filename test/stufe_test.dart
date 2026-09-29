import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  test('liefert erwartete Anzeigenamen und Kurzformen', () {
    expect(Stufe.woelfling.displayName, 'Wölfling');
    expect(Stufe.jungpfadfinder.shortDisplayName, 'Jufi');
    expect(Stufe.leitung.shortDisplayName, 'Leitung');
  });

  test('liefert erwartete Reihenfolge und Altersgrenzen', () {
    expect(Stufe.biber.order, 1);
    expect(Stufe.rover.order, 5);
    expect(Stufe.pfadfinder.defaultMinAge, 12);
    expect(Stufe.leitung.defaultMaxAge, 99);
  });

  test('liefert die naechste Stufe oder null', () {
    expect(Stufe.biber.nextStufe, Stufe.woelfling);
    expect(Stufe.pfadfinder.nextStufe, Stufe.rover);
    expect(Stufe.rover.nextStufe, isNull);
    expect(Stufe.leitung.nextStufe, isNull);
  });
}
