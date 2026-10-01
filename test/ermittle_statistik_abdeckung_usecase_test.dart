import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/bundesstatistik/ermittle_statistik_abdeckung_usecase.dart';
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';

const _bezirk = ArbeitskontextLayer(
  id: 1,
  name: 'Bezirk',
  layerTyp: 'Group::Bezirk',
);
const _stamm = ArbeitskontextLayer(
  id: 11,
  name: 'Stamm',
  layerTyp: 'Group::Stamm',
  parentLayerId: 1,
);

ArbeitskontextReadModel _readModel() => ArbeitskontextReadModel(
  arbeitskontext: Arbeitskontext(
    aktiverLayer: _stamm,
    verfuegbareLayer: const [_bezirk, _stamm],
  ),
  gruppen: const <ArbeitskontextGruppe>[
    ArbeitskontextGruppe(id: 20, name: 'Vorstand', layerId: 11),
    ArbeitskontextGruppe(
      id: 21,
      name: 'Meute 1',
      layerId: 11,
      gruppenTyp: 'Group::StammGruppeWoelflinge',
    ),
    ArbeitskontextGruppe(
      id: 22,
      name: 'Meute 2',
      layerId: 11,
      gruppenTyp: 'Group::StammGruppeWoelflinge',
    ),
    ArbeitskontextGruppe(id: 30, name: 'Leitungsteam', layerId: 11),
    ArbeitskontextGruppe(
      id: 31,
      name: 'Trupp',
      layerId: 11,
      parentId: 30,
      gruppenTyp: 'Group::StammGruppeJungpfadfinder',
    ),
  ],
);

AuthProfile _profil(List<(int, List<String>)> rollen) => AuthProfile(
  namiId: 7,
  roles: [
    for (final (gruppe, rechte) in rollen)
      AuthProfileRole(
        groupId: gruppe,
        groupName: 'Gruppe $gruppe',
        roleName: 'Rolle',
        roleClass: 'Group::Rolle',
        permissions: rechte,
      ),
  ],
);

void main() {
  const useCase = ErmittleStatistikAbdeckungUseCase();
  StatistikAbdeckung abdeckung(List<(int, List<String>)> rollen) =>
      useCase(profile: _profil(rollen), readModel: _readModel());

  test('layer_read in einer Gruppe des Stammes sieht den ganzen Stamm', () {
    expect(
      abdeckung([
        (20, ['layer_read']),
      ]),
      const StatistikAbdeckung.stamm(),
    );
  });

  test('layer_and_below auf dem Bezirk sieht den ganzen Stamm', () {
    expect(
      abdeckung([
        (1, ['layer_and_below_read']),
      ]),
      const StatistikAbdeckung.stamm(),
    );
  });

  test('layer_and_below in einer unbekannten Bezirksgruppe gilt als Stamm', () {
    expect(
      abdeckung([
        (999, ['layer_and_below_full', 'contact_data']),
      ]),
      const StatistikAbdeckung.stamm(),
    );
  });

  test('layer_read in einem anderen Layer zaehlt nicht', () {
    expect(
      abdeckung([
        (999, ['layer_read']),
        (21, ['group_read']),
      ]),
      StatistikAbdeckung.gruppen({21}),
    );
  });

  test('group_read sieht nur die eigene Gruppe', () {
    expect(
      abdeckung([
        (21, ['group_read']),
      ]),
      StatistikAbdeckung.gruppen({21}),
    );
  });

  test('mehrere Gruppenrollen ergeben mehrere Gruppen', () {
    expect(
      abdeckung([
        (21, ['group_read']),
        (22, ['GROUP_FULL']),
      ]),
      StatistikAbdeckung.gruppen({21, 22}),
    );
  });

  test('group_and_below schliesst Untergruppen ein', () {
    expect(
      abdeckung([
        (30, ['group_and_below_read']),
      ]),
      StatistikAbdeckung.gruppen({30, 31}),
    );
  });

  test('ohne passende Rechte bleibt die Teilsicht leer', () {
    expect(
      abdeckung([
        (21, ['contact_data']),
      ]),
      StatistikAbdeckung.gruppen(const <int>{}),
    );
  });
}
