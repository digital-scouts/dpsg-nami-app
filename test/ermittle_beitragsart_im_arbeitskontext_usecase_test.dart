import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/domain/member_filters/usecases/ermittle_beitragsart_im_arbeitskontext_usecase.dart';

void main() {
  const useCase = ErmittleBeitragsartImArbeitskontextUseCase();

  ArbeitskontextReadModel buildReadModel({
    required List<ArbeitskontextMitgliedsZuordnung> zuordnungen,
  }) {
    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
      ),
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
        Mitglied.peopleListItem(
          mitgliedsnummer: '2',
          vorname: 'Mara',
          nachname: 'Schmidt',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(id: 21, name: 'Mitglieder', layerId: 11),
      ],
      mitgliedsZuordnungen: zuordnungen,
    );
  }

  test('ermittelt Beitragsarten aus Rollentypen', () {
    final result = useCase(
      buildReadModel(
        zuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::OrdentlicheMitgliedschaft',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::Zweitmitgliedschaft',
          ),
        ],
      ),
    );

    expect(result['1'], Beitragsart.ordentlicheMitgliedschaft);
    expect(result['2'], Beitragsart.zweitmitgliedschaft);
  });

  test('nutzt fuer die Anzeige die erste gefundene Beitragsart', () {
    final result = useCase(
      buildReadModel(
        zuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::Foerdermitgliedschaft',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::OrdentlicheMitgliedschaft',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::Zweitmitgliedschaft',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2',
            gruppenId: 21,
            rollenTyp: 'Group::Mitglieder::Foerdermitgliedschaft',
          ),
        ],
      ),
    );

    expect(result['1'], Beitragsart.foerdermitgliedschaft);
    expect(result['2'], Beitragsart.zweitmitgliedschaft);
  });

  test('ignoriert nicht relevante Rollentypen', () {
    final result = useCase(
      buildReadModel(
        zuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenTyp: 'Group::Stamm::Leitung',
          ),
        ],
      ),
    );

    expect(result, isEmpty);
  });

  test(
    'ueberspringt fachfremde Rollen bis zur ersten Mitgliedschaftsrolle',
    () {
      final result = useCase(
        buildReadModel(
          zuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
            ArbeitskontextMitgliedsZuordnung(
              mitgliedsnummer: '1',
              gruppenId: 21,
              rollenTyp: 'Group::Stamm::Leitung',
            ),
            ArbeitskontextMitgliedsZuordnung(
              mitgliedsnummer: '1',
              gruppenId: 21,
              rollenTyp: 'Group::Mitglieder::OrdentlicheMitgliedschaft',
            ),
          ],
        ),
      );

      expect(result['1'], Beitragsart.ordentlicheMitgliedschaft);
    },
  );
}
