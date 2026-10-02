import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/qualifikation/hitobito_qualifikationsart.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';

void main() {
  test('leitet je Art-ID eine Art ab, sortiert nach Label', () {
    final arten = HitobitoQualifikationsart.ausQualifikationen(<Qualifikation>[
      const Qualifikation(
        id: 1,
        personId: 10,
        artId: 14,
        label: 'Präventionsschulung',
        gueltigkeitJahre: 5,
      ),
      const Qualifikation(
        id: 2,
        personId: 11,
        artId: 14,
        label: 'Präventionsschulung',
        gueltigkeitJahre: 5,
      ),
      const Qualifikation(
        id: 3,
        personId: 10,
        artId: 21,
        label: 'Juleica',
        gueltigkeitJahre: 3,
        reaktivierbar: true,
      ),
      // Alter Cache ohne Art-ID: keine eigene Art.
      const Qualifikation(id: 4, personId: 12, label: 'Woodbadge'),
    ]);

    expect(arten, const <HitobitoQualifikationsart>[
      HitobitoQualifikationsart(
        id: 21,
        label: 'Juleica',
        gueltigkeitJahre: 3,
        reaktivierbar: true,
      ),
      HitobitoQualifikationsart(
        id: 14,
        label: 'Präventionsschulung',
        gueltigkeitJahre: 5,
      ),
    ]);
  });

  test('uebernimmt die Gueltigkeit im JSON-Rundlauf', () {
    const qualifikation = Qualifikation(
      id: 7,
      personId: 3,
      artId: 9,
      label: 'Erste-Hilfe-Kurs',
      gueltigkeitJahre: 2,
    );

    expect(Qualifikation.fromJson(qualifikation.toJson()), qualifikation);
  });
}
