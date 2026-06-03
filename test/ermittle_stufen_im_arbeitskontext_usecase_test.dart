import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  const useCase = ErmittleStufenImArbeitskontextUseCase();

  ArbeitskontextReadModel buildReadModel({
    List<Mitglied>? mitglieder,
    required List<ArbeitskontextGruppe> gruppen,
    required List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen,
  }) {
    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
      ),
      mitglieder:
          mitglieder ??
          <Mitglied>[
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
            name: 'Biber',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeBiber',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Juffis',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeJungpfadfinder',
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

    expect(result['1'], const <Stufe>{Stufe.biber});
    expect(result['2'], const <Stufe>{Stufe.jungpfadfinder});
  });

  test('fasst mehrere Gruppen derselben Stufe fuer ein Mitglied zusammen', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Fuechse',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeWoelflinge',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Woelfe',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeWoelflinge',
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

  test('bildet alle fuenf Stamm-Gruppentypen auf getrennte Stufen ab', () {
    final result = useCase(
      buildReadModel(
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Ben',
            nachname: 'Biber',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Willi',
            nachname: 'Woelfling',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '3',
            vorname: 'Jana',
            nachname: 'Jufi',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '4',
            vorname: 'Paul',
            nachname: 'Pfadi',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '5',
            vorname: 'Rita',
            nachname: 'Rover',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Biber',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeBiber',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Woelflinge',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeWoelflinge',
          ),
          ArbeitskontextGruppe(
            id: 23,
            name: 'Juffis',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeJungpfadfinder',
          ),
          ArbeitskontextGruppe(
            id: 24,
            name: 'Pfadis',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppePfadfinder',
          ),
          ArbeitskontextGruppe(
            id: 25,
            name: 'Rover',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeRover',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 21),
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '2', gruppenId: 22),
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '3', gruppenId: 23),
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '4', gruppenId: 24),
          ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '5', gruppenId: 25),
        ],
      ),
    );

    expect(result['1'], const <Stufe>{Stufe.biber});
    expect(result['2'], const <Stufe>{Stufe.woelfling});
    expect(result['3'], const <Stufe>{Stufe.jungpfadfinder});
    expect(result['4'], const <Stufe>{Stufe.pfadfinder});
    expect(result['5'], const <Stufe>{Stufe.rover});
  });

  test('ordnet Biber ueber den konfigurierten Stamm-Gruppentyp zu', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Bibergruppe',
            layerId: 11,
            gruppenTyp: 'Group::StammGruppeBiber',
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

    expect(result['1'], const <Stufe>{Stufe.biber});
  });

  test('ignoriert unbekannte Rollen in bekannten Gruppentypen nicht', () {
    final result = useCase(
      buildReadModel(
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Leitungsteam',
            layerId: 11,
            gruppenTyp: 'Group::Foobar',
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

    expect(result, isEmpty);
  });
}
