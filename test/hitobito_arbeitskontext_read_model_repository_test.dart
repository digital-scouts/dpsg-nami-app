import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/data/arbeitskontext/hitobito_person_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_people_service.dart';

void main() {
  test(
    'refresh mappt erreichbare Layer und Nicht-Layer-Gruppen in den aktiven Kontext',
    () async {
      final localRepository = _FakeArbeitskontextLocalRepository();
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              parentId: 5,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 20,
              name: 'Bezirk Rhein',
              isLayer: true,
              parentId: 1,
              layerGroupId: 20,
            ),
            HitobitoGroupResource(
              id: 101,
              name: 'Woelflinge',
              isLayer: false,
              parentId: 11,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 102,
              name: 'Jungpfadfinder',
              isLayer: false,
              parentId: 11,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 201,
              name: 'Bezirksteam',
              isLayer: false,
              parentId: 20,
              layerGroupId: 20,
            ),
          ],
        ),
        peopleService: _FakeHitobitoPeopleService(
          people: const <HitobitoPersonResource>[
            HitobitoPersonResource(
              id: 1,
              firstName: 'Julia',
              lastName: 'Keller',
              membershipNumber: 1001,
              primaryGroupId: 101,
            ),
            HitobitoPersonResource(
              id: 2,
              firstName: 'Max',
              lastName: 'Muster',
              membershipNumber: 1002,
              primaryGroupId: 201,
            ),
          ],
        ),
        localRepository: localRepository,
      );

      final readModel = await repository.refresh(
        accessToken: 'token-123',
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
      );

      expect(readModel.arbeitskontext.aktiverLayer.id, 11);
      expect(readModel.arbeitskontext.verfuegbareLayer, hasLength(1));
      expect(readModel.arbeitskontext.verfuegbareLayer.single.id, 20);
      expect(
        readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
        <String>['1001'],
      );
      expect(readModel.gruppen.map((gruppe) => gruppe.id), <int>[101, 102]);
      expect(localRepository.saved, readModel);
    },
  );

  test(
    'loadCached liefert bei anderem Layer einen leeren Kontext zurueck',
    () async {
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(),
        peopleService: _FakeHitobitoPeopleService(),
        localRepository: _FakeArbeitskontextLocalRepository(
          cached: ArbeitskontextReadModel(
            arbeitskontext: Arbeitskontext(
              aktiverLayer: const ArbeitskontextLayer(
                id: 20,
                name: 'Bezirk Rhein',
              ),
            ),
          ),
        ),
      );

      final cached = await repository.loadCached(
        Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
      );

      expect(cached.arbeitskontext.aktiverLayer.id, 11);
      expect(cached.gruppen, isEmpty);
      expect(cached.mitglieder, isEmpty);
    },
  );
}

class _FakeArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  _FakeArbeitskontextLocalRepository({this.cached});

  final ArbeitskontextReadModel? cached;
  ArbeitskontextReadModel? saved;

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => cached;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {
    saved = readModel;
  }
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService({
    List<HitobitoGroupResource> groups = const <HitobitoGroupResource>[],
  }) : _groups = groups,
       super(
         config: const HitobitoAuthConfig(
           clientId: 'client',
           clientSecret: 'secret',
           authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
           tokenUrl: 'https://demo.hitobito.com/oauth/token',
           redirectUri: 'de.jlange.nami.app:/oauth/callback',
           scopeString: 'openid email',
           discoveryUrl: '',
           profileUrl: 'https://demo.hitobito.com/oauth/profile',
         ),
       );

  final List<HitobitoGroupResource> _groups;

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => _groups;
}

class _FakeHitobitoPeopleService extends HitobitoPeopleService {
  _FakeHitobitoPeopleService({
    List<HitobitoPersonResource> people = const <HitobitoPersonResource>[],
  }) : _people = people,
       super(
         config: const HitobitoAuthConfig(
           clientId: 'client',
           clientSecret: 'secret',
           authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
           tokenUrl: 'https://demo.hitobito.com/oauth/token',
           redirectUri: 'de.jlange.nami.app:/oauth/callback',
           scopeString: 'openid email',
           discoveryUrl: '',
           profileUrl: 'https://demo.hitobito.com/oauth/profile',
         ),
       );

  final List<HitobitoPersonResource> _people;

  @override
  Future<List<HitobitoPersonResource>> fetchPeopleResources(
    String accessToken,
  ) async => _people;
}
