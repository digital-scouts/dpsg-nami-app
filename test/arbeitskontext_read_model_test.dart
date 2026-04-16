import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';

void main() {
  group('ArbeitskontextReadModel', () {
    final arbeitskontext = Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
      verfuegbareLayer: const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
      ],
    );

    test('haelt Personen und Gruppen fuer genau einen aktiven Layer', () {
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: arbeitskontext,
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1001',
            vorname: 'Anna',
            nachname: 'Beispiel',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
        ],
      );

      expect(readModel.arbeitskontext, arbeitskontext);
      expect(readModel.hatMitglieder, isTrue);
      expect(readModel.hatGruppen, isTrue);
      expect(readModel.findeMitglied('1001')?.vorname, 'Anna');
      expect(readModel.findeGruppe(101)?.name, 'Woelflinge');
    });

    test('normalisiert doppelte Mitglieder ueber die Mitgliedsnummer', () {
      final anna = Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Anna',
        nachname: 'Beispiel',
      );
      final duplicateAnna = Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Anna Maria',
        nachname: 'Beispiel',
      );

      final readModel = ArbeitskontextReadModel(
        arbeitskontext: arbeitskontext,
        mitglieder: <Mitglied>[anna, duplicateAnna],
      );

      expect(readModel.mitglieder, <Mitglied>[anna]);
    });

    test('normalisiert doppelte Gruppen ueber die Gruppen-ID', () {
      const gruppe = ArbeitskontextGruppe(
        id: 101,
        name: 'Woelflinge',
        layerId: 11,
      );
      const duplicateGruppe = ArbeitskontextGruppe(
        id: 101,
        name: 'Woelflinge Duplikat',
        layerId: 11,
      );

      final readModel = ArbeitskontextReadModel(
        arbeitskontext: arbeitskontext,
        gruppen: const <ArbeitskontextGruppe>[gruppe, duplicateGruppe],
      );

      expect(readModel.gruppen, const <ArbeitskontextGruppe>[gruppe]);
    });

    test(
      'normalisiert doppelte Mitgliedszuordnungen ueber Mitglied, Gruppe und Rolle',
      () {
        const zuordnung = ArbeitskontextMitgliedsZuordnung(
          mitgliedsnummer: '1001',
          gruppenId: 101,
          rollenTyp: 'Group::Mitglied',
          rollenLabel: 'Mitglied',
        );
        const duplicate = ArbeitskontextMitgliedsZuordnung(
          mitgliedsnummer: '1001',
          gruppenId: 101,
          rollenTyp: 'Group::Mitglied',
          rollenLabel: 'Mitglied',
        );

        final readModel = ArbeitskontextReadModel(
          arbeitskontext: arbeitskontext,
          gruppen: const <ArbeitskontextGruppe>[
            ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
          ],
          mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
            zuordnung,
            duplicate,
          ],
        );

        expect(
          readModel.mitgliedsZuordnungen,
          const <ArbeitskontextMitgliedsZuordnung>[zuordnung],
        );
      },
    );

    test('liefert unveraenderliche Listen', () {
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: arbeitskontext,
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1001',
            vorname: 'Anna',
            nachname: 'Beispiel',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
        ],
      );

      expect(
        () => readModel.mitglieder.add(
          Mitglied.peopleListItem(
            mitgliedsnummer: '1002',
            vorname: 'Ben',
            nachname: 'Beispiel',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => readModel.gruppen.add(
          const ArbeitskontextGruppe(id: 102, name: 'Pfadis', layerId: 11),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => readModel.mitgliedsZuordnungen.add(
          const ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1001',
            gruppenId: 101,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('weist Gruppen aus anderen Layern zurueck', () {
      expect(
        () => ArbeitskontextReadModel(
          arbeitskontext: arbeitskontext,
          gruppen: const <ArbeitskontextGruppe>[
            ArbeitskontextGruppe(id: 201, name: 'Bezirksteam', layerId: 20),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
