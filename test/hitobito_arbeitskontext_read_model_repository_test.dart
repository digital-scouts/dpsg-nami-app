import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/data/arbeitskontext/hitobito_person_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
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
              roles: <HitobitoPersonRoleResource>[
                HitobitoPersonRoleResource(
                  id: 501,
                  personId: 1,
                  groupId: 101,
                  roleType: 'Group::Leiter',
                  roleLabel: 'Leitung',
                ),
                HitobitoPersonRoleResource(
                  id: 502,
                  personId: 1,
                  groupId: 102,
                  roleType: 'Group::Mitglied',
                  roleLabel: 'Mitglied',
                ),
              ],
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
      expect(readModel.arbeitskontext.verfuegbareLayer, isEmpty);
      expect(
        readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
        <String>['1001'],
      );
      expect(readModel.gruppen.map((gruppe) => gruppe.id), <int>[101, 102]);
      expect(
        readModel.mitgliedsZuordnungen,
        const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1001',
            gruppenId: 101,
            rollenTyp: 'Group::Leiter',
            rollenLabel: 'Leitung',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1001',
            gruppenId: 102,
            rollenTyp: 'Group::Mitglied',
            rollenLabel: 'Mitglied',
          ),
        ],
      );
      expect(localRepository.saved, readModel);
    },
  );

  test(
    'refresh behaelt Personen mit Layer-Zugehoerigkeit ueber Rollen auch ohne passende primary_group',
    () async {
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 101,
              name: 'Woelflinge',
              isLayer: false,
              parentId: 11,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 999,
              name: 'Fremde Gruppe',
              isLayer: false,
              parentId: 99,
              layerGroupId: 99,
            ),
          ],
        ),
        peopleService: _FakeHitobitoPeopleService(
          people: const <HitobitoPersonResource>[
            HitobitoPersonResource(
              id: 1,
              firstName: 'Julia',
              lastName: 'Keller',
              primaryGroupId: 999,
              membershipNumber: 1001,
              roles: <HitobitoPersonRoleResource>[
                HitobitoPersonRoleResource(
                  id: 501,
                  personId: 1,
                  groupId: 101,
                  roleType: 'Group::Leiter',
                  roleLabel: 'Leitung',
                ),
              ],
            ),
          ],
        ),
        localRepository: _FakeArbeitskontextLocalRepository(),
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

      expect(
        readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
        <String>['1001'],
      );
      expect(
        readModel.mitgliedsZuordnungen.map((zuordnung) => zuordnung.gruppenId),
        <int>[101],
      );
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

  test(
    'refresh ersetzt beim Kontextwechsel den lokalen Cache vollstaendig mit erweitertem Personenmodell und Zuordnungen',
    () async {
      final localRepository = _FakeArbeitskontextLocalRepository();
      final firstRepository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 20,
              name: 'Bezirk Rhein',
              isLayer: true,
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
              pronoun: 'sie/ihr',
              emailAdressen: <MitgliedKontaktEmail>[
                MitgliedKontaktEmail(
                  wert: 'julia@example.org',
                  label: Mitglied.primaryEmailLabel,
                  istPrimaer: true,
                ),
              ],
              telefonnummern: <MitgliedKontaktTelefon>[
                MitgliedKontaktTelefon(wert: '+49 170 1234567', label: 'Mobil'),
              ],
              adressen: <MitgliedKontaktAdresse>[
                MitgliedKontaktAdresse(
                  street: 'Musterweg',
                  housenumber: '4',
                  zipCode: '12345',
                  town: 'Musterdorf',
                  country: 'DE',
                ),
              ],
              roles: <HitobitoPersonRoleResource>[
                HitobitoPersonRoleResource(
                  id: 501,
                  personId: 1,
                  groupId: 101,
                  roleType: 'Group::Leiter',
                  roleLabel: 'Leitung',
                ),
              ],
            ),
          ],
        ),
        localRepository: localRepository,
      );

      final firstReadModel = await firstRepository.refresh(
        accessToken: 'token-123',
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
          ],
        ),
      );

      final secondRepository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 20,
              name: 'Bezirk Rhein',
              isLayer: true,
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
              id: 2,
              firstName: 'Mara',
              lastName: 'Schmidt',
              membershipNumber: 2001,
              primaryGroupId: 201,
              emailAdressen: <MitgliedKontaktEmail>[
                MitgliedKontaktEmail(
                  wert: 'mara@example.org',
                  label: Mitglied.primaryEmailLabel,
                  istPrimaer: true,
                ),
                MitgliedKontaktEmail(
                  wert: 'familie@example.org',
                  label: 'Familie',
                ),
              ],
              telefonnummern: <MitgliedKontaktTelefon>[
                MitgliedKontaktTelefon(
                  wert: '+49 40 9876543',
                  label: 'Festnetz',
                ),
              ],
              adressen: <MitgliedKontaktAdresse>[
                MitgliedKontaktAdresse(
                  label: 'Post',
                  postbox: 'PF 12',
                  zipCode: '50669',
                  town: 'Koeln',
                  country: 'DE',
                ),
              ],
              roles: <HitobitoPersonRoleResource>[
                HitobitoPersonRoleResource(
                  id: 601,
                  personId: 2,
                  groupId: 201,
                  roleType: 'Group::Bezirk::Vorstand',
                  roleLabel: 'Vorstand',
                ),
              ],
            ),
          ],
        ),
        localRepository: localRepository,
      );

      final secondReadModel = await secondRepository.refresh(
        accessToken: 'token-123',
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
          ],
        ),
      );

      expect(localRepository.saved, secondReadModel);
      expect(localRepository.saved, isNot(firstReadModel));
      expect(
        localRepository.saved?.mitglieder.map(
          (mitglied) => mitglied.mitgliedsnummer,
        ),
        <String>['2001'],
      );
      expect(localRepository.saved?.findeMitglied('1001'), isNull);
      expect(localRepository.saved?.findeGruppe(101), isNull);
      expect(localRepository.saved?.findeGruppe(201)?.name, 'Bezirksteam');
      expect(
        localRepository.saved?.findeMitglied('2001')?.emailAdressen,
        const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            wert: 'mara@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
          MitgliedKontaktEmail(wert: 'familie@example.org', label: 'Familie'),
        ],
      );
      expect(
        localRepository.saved?.findeMitglied('2001')?.telefonnummern,
        const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(wert: '+49 40 9876543', label: 'Festnetz'),
        ],
      );
      expect(
        localRepository.saved?.findeMitglied('2001')?.adressen,
        const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            label: 'Post',
            postbox: 'PF 12',
            zipCode: '50669',
            town: 'Koeln',
            country: 'DE',
          ),
        ],
      );
      expect(
        localRepository.saved?.mitgliedsZuordnungen,
        const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2001',
            gruppenId: 201,
            rollenTyp: 'Group::Bezirk::Vorstand',
            rollenLabel: 'Vorstand',
          ),
        ],
      );
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
