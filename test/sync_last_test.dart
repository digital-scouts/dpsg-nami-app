import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_efz_service.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/hitobito_qualifications_service.dart';
import 'package:nami/services/hitobito_roles_service.dart';

import 'support/fake_graphiti_list_api.dart';

/// Request-Zahl eines Syncs gegen eine Graphiti-Nachbildung. Szenario:
/// Leitung mit DV-Leserechten, aktiver Layer ist ein Stamm mit 40 Personen,
/// lesbar sind insgesamt 3.000 Personen mit je einer Qualifikation und einem
/// EFZ-Eintrag.
void main() {
  const stammId = 3;
  const woelflingeId = 31;
  const dvId = 2;
  const personenGesamt = 3000;
  const personenImStamm = 40;

  final config = HitobitoAuthConfig.fromBaseUrl(
    clientId: 'client',
    clientSecret: 'secret',
    baseUrl: 'https://demo.hitobito.com',
    redirectUri: 'de.jlange.nami.app:/oauth/callback',
    scopeString: 'openid email api',
  );

  FakeGraphitiListApi graphitiMitDv() {
    final api = FakeGraphitiListApi();
    api.setze('groups', <GraphitiRecord>[
      _gruppe(1, 'Bund', layer: true),
      _gruppe(dvId, 'DV Musterland', layer: true, parentId: 1),
      _gruppe(stammId, 'Stamm Musterdorf', layer: true, parentId: dvId),
      _gruppe(
        woelflingeId,
        'Woelflinge',
        parentId: stammId,
        layerGroupId: stammId,
      ),
    ]);
    api.setze('people', <GraphitiRecord>[
      for (var id = 1; id <= personenGesamt; id++)
        GraphitiRecord(
          id: id,
          attributes: <String, dynamic>{
            'first_name': 'Person',
            'last_name': '$id',
            'membership_number': 100000 + id,
            'primary_group_id': id <= personenImStamm ? woelflingeId : dvId,
          },
        ),
    ]);
    api.setze('roles', <GraphitiRecord>[
      for (var id = 1; id <= personenImStamm; id++)
        GraphitiRecord(
          id: 5000 + id,
          attributes: <String, dynamic>{
            'person_id': id,
            'group_id': woelflingeId,
            'type': 'Group::Woelflinge::Mitglied',
            'label': 'Mitglied',
          },
        ),
    ]);
    api.setze('qualifications', <GraphitiRecord>[
      for (var id = 1; id <= personenGesamt; id++)
        GraphitiRecord(
          id: 7000 + id,
          attributes: <String, dynamic>{
            'person_id': id,
            'qualification_kind_id': 5,
            'qualified_at': '2024-05-01',
          },
          included: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '5',
              'type': 'qualification_kinds',
              'attributes': <String, dynamic>{
                'label': 'Juleica',
                'validity': 3,
                'reactivateable': 2,
              },
            },
          ],
        ),
    ]);
    api.setze('efz_einsichtnahmen', <GraphitiRecord>[
      for (var id = 1; id <= personenGesamt; id++)
        GraphitiRecord(
          id: 9000 + id,
          attributes: <String, dynamic>{
            'person_id': id,
            'issued_on': '2024-01-15',
            'einsicht_on': '2024-02-01',
          },
        ),
    ]);
    return api;
  }

  HitobitoArbeitskontextReadModelRepository repositoryFuer(
    FakeGraphitiListApi api,
  ) {
    return HitobitoArbeitskontextReadModelRepository(
      groupsService: HitobitoGroupsService(
        config: config,
        httpClient: api.client,
      ),
      peopleService: HitobitoPeopleService(
        config: config,
        httpClient: api.client,
      ),
      rolesService: HitobitoRolesService(
        config: config,
        httpClient: api.client,
      ),
      efzService: HitobitoEfzService(config: config, httpClient: api.client),
      qualificationsService: HitobitoQualificationsService(
        config: config,
        httpClient: api.client,
      ),
      localRepository: _InMemoryLocalRepository(),
    );
  }

  test('Sync eines Stamms mit DV-Leserechten', () async {
    final api = graphitiMitDv();

    final readModel = await repositoryFuer(api).refresh(
      accessToken: 'token-123',
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(
          id: stammId,
          name: 'Stamm Musterdorf',
        ),
      ),
    );

    expect(readModel.mitglieder, hasLength(personenImStamm));
    expect(readModel.qualifikationen, hasLength(personenImStamm));
    expect(readModel.efzEinsichtnahmen, hasLength(personenImStamm));
    // Qualifikationen und EFZ ueber alle 3.000 lesbaren Personen. Vorher in
    // 20er-Seiten je 150 Requests, mit page[size]=1000 je 3.
    expect(api.anfragenJeRessource(), <String, int>{
      'groups': 1,
      'roles': 2,
      'people': 1,
      'efz_einsichtnahmen': 3,
      'qualifications': 3,
    });
  });
}

GraphitiRecord _gruppe(
  int id,
  String name, {
  bool layer = false,
  int? parentId,
  int? layerGroupId,
}) {
  return GraphitiRecord(
    id: id,
    attributes: <String, dynamic>{
      'name': name,
      'layer': layer,
      'parent_id': parentId,
      'layer_group_id': layerGroupId ?? (layer ? id : null),
      'type': layer ? 'Group::Stamm' : 'Group::Woelflinge',
      'zip_code': 12345,
    },
  );
}

class _InMemoryLocalRepository implements ArbeitskontextLocalRepository {
  ArbeitskontextReadModel? cached;

  @override
  Future<void> clearCached() async {
    cached = null;
  }

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => cached;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {
    cached = readModel;
  }
}
