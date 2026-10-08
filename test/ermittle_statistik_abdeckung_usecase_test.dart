import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/bundesstatistik/ermittle_statistik_abdeckung_usecase.dart';
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';
import 'package:nami/domain/member/mitglied.dart';

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

/// Die eigene Person (`namiId` 7) hat die Mitgliedsnummer 'eigen'.
final _eigene = Mitglied.peopleListItem(
  vorname: 'Eigene',
  nachname: 'Person',
  mitgliedsnummer: 'eigen',
  personId: 7,
);

/// Standardmaessig liefert Hitobito fuer alle Gruppen auch fremde Rollen.
ArbeitskontextReadModel _readModel({
  Set<int> fremdeRollenIn = const {20, 21, 22, 30, 31},
  Set<int> eigeneRollenIn = const {},
}) => ArbeitskontextReadModel(
  // Gruppe 5 ist die Bezirksleitung im Bezirk oberhalb des Stammes.
  uebergeordneteGruppenIds: const [1, 5],
  mitglieder: [_eigene],
  mitgliedsZuordnungen: [
    for (final gruppe in fremdeRollenIn)
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: 'fremd-$gruppe',
        gruppenId: gruppe,
      ),
    for (final gruppe in eigeneRollenIn)
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: 'eigen',
        gruppenId: gruppe,
      ),
  ],
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
  StatistikAbdeckung abdeckung(
    List<(int, List<String>)> rollen, {
    ArbeitskontextReadModel? readModel,
  }) => useCase(profile: _profil(rollen), readModel: readModel ?? _readModel());

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

  test(
    'layer_and_below in einer Gruppe des Bezirks sieht den ganzen Stamm',
    () {
      expect(
        abdeckung([
          (5, ['layer_and_below_full', 'contact_data']),
        ]),
        const StatistikAbdeckung.stamm(),
      );
    },
  );

  test('volle Rechte in einem anderen Stamm wirken hier nicht', () {
    // Gruppe 777 liegt in Stamm A, der aktive Layer ist Stamm B.
    expect(
      abdeckung([
        (777, ['layer_and_below_full']),
        (21, ['group_read']),
      ]),
      StatistikAbdeckung.gruppen({21}),
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
      StatistikAbdeckung.gruppen({21, 22}, vollLesbareGruppenIds: {22}),
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

  group('ohne Rollen anderer Personen', () {
    test('group_read ohne fremde Rollen ist eine Gruppe ohne Rollen', () {
      expect(
        abdeckung([
          (21, ['group_read']),
        ], readModel: _readModel(fremdeRollenIn: {}, eigeneRollenIn: {21})),
        StatistikAbdeckung.gruppen(const <int>{}, gruppenOhneRollen: {21}),
      );
    });

    test('group_full zaehlt auch ohne fremde Rollen', () {
      expect(
        abdeckung([
          (21, ['group_full']),
        ], readModel: _readModel(fremdeRollenIn: {})),
        StatistikAbdeckung.gruppen({21}, vollLesbareGruppenIds: {21}),
      );
    });

    test('group_and_below_read zaehlt, wenn eine Untergruppe Rollen hat', () {
      expect(
        abdeckung([
          (30, ['group_and_below_read']),
        ], readModel: _readModel(fremdeRollenIn: {31})),
        StatistikAbdeckung.gruppen({30, 31}),
      );
    });

    test('group_and_below_read ohne fremde Rollen fehlt ganz', () {
      expect(
        abdeckung([
          (30, ['group_and_below_read']),
        ], readModel: _readModel(fremdeRollenIn: {21})),
        StatistikAbdeckung.gruppen(const <int>{}, gruppenOhneRollen: {30, 31}),
      );
    });

    test('eine voll lesbare Rolle schliesst die Gruppe aus der Luecke aus', () {
      expect(
        abdeckung([
          (21, ['group_read']),
          (30, ['group_and_below_full']),
        ], readModel: _readModel(fremdeRollenIn: {})),
        StatistikAbdeckung.gruppen(
          {30, 31},
          gruppenOhneRollen: {21},
          vollLesbareGruppenIds: {30, 31},
        ),
      );
    });
  });

  group('istVollLesbar', () {
    test('bei Stamm-Abdeckung ist jede Person voll lesbar', () {
      expect(const StatistikAbdeckung.stamm().istVollLesbar(const []), isTrue);
    });

    test('nur Personen mit Rolle in voll lesbarer Gruppe', () {
      final abdeckung = StatistikAbdeckung.gruppen(
        {21, 22},
        vollLesbareGruppenIds: {22},
      );
      expect(abdeckung.istVollLesbar([22]), isTrue);
      expect(abdeckung.istVollLesbar([21]), isFalse);
      expect(abdeckung.istVollLesbar(const []), isFalse);
    });
  });
}
