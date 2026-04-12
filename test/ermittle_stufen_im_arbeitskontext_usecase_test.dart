import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  const useCase = ErmittleStufenImArbeitskontextUseCase();

  ArbeitskontextReadModel buildReadModel({
    required List<ArbeitskontextGruppe> gruppen,
    required List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen,
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
      gruppen: gruppen,
      mitgliedsZuordnungen: mitgliedsZuordnungen,
    );
  }

  test('ordnet Mitglieder allein ueber den Gruppentyp Stufen zu', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Woelflinge',
            layerId: 11,
            gruppenTyp: 'Group::Meute',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Pfadis',
            layerId: 11,
            gruppenTyp: 'Group::Sippe',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Irgendeine Rolle',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2',
            gruppenId: 22,
            rollenLabel: 'Noch eine andere Rolle',
          ),
        ],
      ),
    );

    expect(result['1'], const <Stufe>{Stufe.woelfling});
    expect(result['2'], const <Stufe>{Stufe.pfadfinder});
  });

  test('fasst mehrere Gruppen derselben Stufe fuer ein Mitglied zusammen', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Fuechse',
            layerId: 11,
            gruppenTyp: 'Group::Meute',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Woelfe',
            layerId: 11,
            gruppenTyp: 'Group::Meute',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Beliebig',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 22,
            rollenLabel: 'Ebenfalls beliebig',
          ),
        ],
      ),
    );

    expect(result['1'], const <Stufe>{Stufe.woelfling});
  });

  test('liefert fuer leere Konfigurationen noch keine Zuordnung', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Bibergruppe',
            layerId: 11,
            gruppenTyp: 'Group::Biber',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Biber',
          ),
        ],
      ),
    );

    expect(result, isEmpty);
  });

  test('ignoriert unbekannte Rollen in bekannten Gruppentypen nicht', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Roverrunde',
            layerId: 11,
            gruppenTyp: 'Group::Runde',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Komplett unbekannt',
          ),
        ],
      ),
    );

    expect(result['1'], const <Stufe>{Stufe.rover});
  });
}
