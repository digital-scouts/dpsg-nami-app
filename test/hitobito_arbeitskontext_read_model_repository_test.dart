import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/data/arbeitskontext/hitobito_person_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_efz_service.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/hitobito_qualifications_service.dart';
import 'package:nami/services/hitobito_roles_service.dart';

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
              displayName: 'Fuechse',
              groupType: 'Group::Meute',
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
      expect(readModel.findeGruppe(101)?.displayName, 'Fuechse');
      expect(readModel.findeGruppe(101)?.gruppenTyp, 'Group::Meute');
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
    'refresh laedt Gruppen nicht erneut, wenn accessibleGroups bereits uebergeben wird',
    () async {
      final localRepository = _FakeArbeitskontextLocalRepository();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: groupsService,
        peopleService: _FakeHitobitoPeopleService(),
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
        accessibleGroups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );

      expect(groupsService.fetchCallCount, 0);
      expect(readModel.arbeitskontext.aktiverLayer.id, 11);
    },
  );

  test(
    'refresh meldet pro People-Seite ein korrekt gefiltertes Zwischen-Readmodel ueber onProgress',
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
              id: 999,
              name: 'Fremde Gruppe',
              isLayer: false,
              parentId: 88,
              layerGroupId: 88,
            ),
          ],
        ),
        peopleService: _FakeHitobitoPeopleService(
          pages: const <List<HitobitoPersonResource>>[
            <HitobitoPersonResource>[
              HitobitoPersonResource(
                id: 1,
                firstName: 'Julia',
                lastName: 'Keller',
                membershipNumber: 1001,
                primaryGroupId: 11,
              ),
            ],
            <HitobitoPersonResource>[
              // Gehoert zu einer fremden Gruppe/Layer - muss auch im
              // Zwischenstand korrekt herausgefiltert werden.
              HitobitoPersonResource(
                id: 2,
                firstName: 'Fremd',
                lastName: 'Person',
                membershipNumber: 2002,
                primaryGroupId: 999,
              ),
              HitobitoPersonResource(
                id: 3,
                firstName: 'Max',
                lastName: 'Mustermann',
                membershipNumber: 1002,
                primaryGroupId: 11,
              ),
            ],
          ],
        ),
        localRepository: _FakeArbeitskontextLocalRepository(),
      );

      final progressSnapshots = <List<String>>[];
      final readModel = await repository.refresh(
        accessToken: 'token-123',
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
        onProgress: (partial) => progressSnapshots.add(
          partial.mitglieder
              .map((mitglied) => mitglied.mitgliedsnummer)
              .toList(),
        ),
      );

      expect(progressSnapshots, [
        ['1001'],
        ['1001', '1002'],
      ]);
      expect(
        readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
        <String>['1001', '1002'],
      );
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
          people: <HitobitoPersonResource>[
            HitobitoPersonResource(
              id: 2,
              firstName: 'Mara',
              lastName: 'Schmidt',
              membershipNumber: 2001,
              primaryGroupId: 201,
              updatedAt: DateTime(2024, 12, 24, 9, 15),
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
        localRepository.saved?.findeMitglied('2001')?.updatedAt,
        DateTime(2024, 12, 24, 9, 15),
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

  test(
    'loadRoles mappt vollstaendige und historische Roles auf Mitglieder und markiert den Kontext als geladen',
    () async {
      final localRepository = _FakeArbeitskontextLocalRepository();
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(),
        peopleService: _FakeHitobitoPeopleService(),
        rolesService: _FakeHitobitoRolesService(
          roles: <HitobitoPersonRoleResource>[
            HitobitoPersonRoleResource(
              id: 701,
              personId: 1,
              groupId: 101,
              roleType: 'Group::Mitglied',
              roleLabel: 'Mitglied',
              startOn: DateTime(2020, 1, 1),
              endOn: DateTime(2021, 1, 1),
            ),
            HitobitoPersonRoleResource(
              id: 702,
              personId: 1,
              groupId: 11,
              roleType: 'Group::Leiter',
              roleLabel: 'Leitung Stamm',
              startOn: DateTime(2021, 2, 1),
            ),
          ],
        ),
        localRepository: localRepository,
      );
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
        ],
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1001',
            personId: 1,
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
      );

      final loaded = await repository.loadRoles(
        accessToken: 'token-123',
        readModel: readModel,
      );

      expect(loaded.rolesSindGeladen, isTrue);
      expect(localRepository.saved, loaded);
      expect(loaded.findeMitglied('1001')?.roles, <Role>[
        Role(
          id: 701,
          personId: 1,
          groupId: 101,
          type: 'Group::Mitglied',
          label: 'Mitglied',
          startOn: DateTime(2020, 1, 1),
          endOn: DateTime(2021, 1, 1),
          groupName: 'Woelflinge',
          layerName: 'Stamm Musterdorf',
        ),
        Role(
          id: 702,
          personId: 1,
          groupId: 11,
          type: 'Group::Leiter',
          label: 'Leitung Stamm',
          startOn: DateTime(2021, 2, 1),
          groupName: 'Stamm Musterdorf',
          layerName: 'Stamm Musterdorf',
        ),
      ]);
    },
  );

  test('refresh laedt Rollen parallel zu Personen und ordnet sie im finalen '
      'Ergebnis korrekt zu', () async {
    final repository = HitobitoArbeitskontextReadModelRepository(
      groupsService: _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
            layerGroupId: 11,
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
            primaryGroupId: 11,
          ),
        ],
      ),
      rolesService: _FakeHitobitoRolesService(
        roles: <HitobitoPersonRoleResource>[
          HitobitoPersonRoleResource(
            id: 701,
            personId: 1,
            groupId: 11,
            roleType: 'Group::Leiter',
            roleLabel: 'Leitung',
          ),
          HitobitoPersonRoleResource(
            id: 702,
            personId: 1,
            groupId: 90,
            roleType: 'Group::Bezirk::Mitarbeiter',
            roleLabel: 'AK Mitarbeiter*in',
            groupName: 'AK Woelflingsstufe',
            layerName: 'Bezirk Rheinauen',
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

    expect(readModel.rolesSindGeladen, isTrue);
    expect(readModel.findeMitglied('1001')?.roles, <Role>[
      Role(
        id: 701,
        personId: 1,
        groupId: 11,
        type: 'Group::Leiter',
        label: 'Leitung',
        startOn: readModel.findeMitglied('1001')?.eintrittsdatum,
        groupName: 'Stamm Musterdorf',
        layerName: 'Stamm Musterdorf',
      ),
      // Rolle ausserhalb des aktiven Layers behaelt Gruppe und Layer aus der API.
      Role(
        id: 702,
        personId: 1,
        groupId: 90,
        type: 'Group::Bezirk::Mitarbeiter',
        label: 'AK Mitarbeiter*in',
        startOn: readModel.findeMitglied('1001')?.eintrittsdatum,
        groupName: 'AK Woelflingsstufe',
        layerName: 'Bezirk Rheinauen',
      ),
    ]);
  });

  test('refresh liefert weiterhin ein gueltiges Mitglieder-Ergebnis, wenn der '
      'parallele Rollen-Fetch pro Person fehlschlaegt', () async {
    final repository = HitobitoArbeitskontextReadModelRepository(
      groupsService: _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
            layerGroupId: 11,
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
            primaryGroupId: 11,
          ),
        ],
      ),
      rolesService: _FakeHitobitoRolesService(
        roles: <HitobitoPersonRoleResource>[
          HitobitoPersonRoleResource(
            id: 701,
            personId: 1,
            groupId: 11,
            roleType: 'Group::Leiter',
            roleLabel: 'Leitung',
          ),
        ],
        error: const HitobitoRolesException('Rollen nicht erreichbar'),
        errorNurBeiFilter: 'filter[person_id]',
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

    expect(readModel.rolesSindGeladen, isFalse);
    expect(
      readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
      <String>['1001'],
    );
    expect(readModel.findeMitglied('1001')?.roles, isEmpty);
  });

  group('refresh laedt nur Personen des aktiven Layers', () {
    const gruppen = <HitobitoGroupResource>[
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
        id: 20,
        name: 'Stamm Nachbarort',
        isLayer: true,
        layerGroupId: 20,
      ),
      HitobitoGroupResource(
        id: 201,
        name: 'Pfadfinder',
        isLayer: false,
        parentId: 20,
        layerGroupId: 20,
      ),
    ];
    final arbeitskontext = Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
    );
    final rolleImLayer = HitobitoPersonRoleResource(
      id: 702,
      personId: 2,
      groupId: 101,
      roleType: 'Group::Leiter',
      roleLabel: 'Leitung',
    );
    final rolleAusserhalb = HitobitoPersonRoleResource(
      id: 703,
      personId: 2,
      groupId: 201,
      roleType: 'Group::Mitglied',
      roleLabel: 'Mitglied',
    );

    test('ueber Hauptgruppe oder Rolle und behaelt Rollen ausserhalb des '
        'Layers', () async {
      final peopleService = _FakeHitobitoPeopleService(
        people: <HitobitoPersonResource>[
          const HitobitoPersonResource(
            id: 1,
            firstName: 'Julia',
            lastName: 'Keller',
            membershipNumber: 1001,
            primaryGroupId: 11,
          ),
          HitobitoPersonResource(
            id: 2,
            firstName: 'Max',
            lastName: 'Mustermann',
            membershipNumber: 1002,
            primaryGroupId: 201,
            roles: <HitobitoPersonRoleResource>[rolleImLayer, rolleAusserhalb],
          ),
          const HitobitoPersonResource(
            id: 3,
            firstName: 'Lea',
            lastName: 'Nachbar',
            membershipNumber: 1003,
            primaryGroupId: 201,
          ),
        ],
      );
      final rolesService = _FakeHitobitoRolesService(
        roles: <HitobitoPersonRoleResource>[
          rolleImLayer,
          rolleAusserhalb,
          HitobitoPersonRoleResource(
            id: 704,
            personId: 3,
            groupId: 201,
            roleType: 'Group::Mitglied',
            roleLabel: 'Mitglied',
          ),
        ],
      );
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(groups: gruppen),
        peopleService: peopleService,
        rolesService: rolesService,
        localRepository: _FakeArbeitskontextLocalRepository(),
      );

      final readModel = await repository.refresh(
        accessToken: 'token-123',
        arbeitskontext: arbeitskontext,
      );

      expect(rolesService.requestedFilters, <Map<String, String>>[
        <String, String>{'filter[group_id]': '11,101'},
        <String, String>{'filter[person_id]': '1,2'},
      ]);
      expect(peopleService.requestedFilters, <Map<String, String>>[
        <String, String>{'filter[primary_group_id]': '11,101'},
        <String, String>{'filter[id]': '2'},
      ]);
      expect(
        readModel.mitglieder.map((mitglied) => mitglied.mitgliedsnummer),
        <String>['1001', '1002'],
      );
      expect(
        readModel.findeMitglied('1002')?.roles.map((role) => role.id),
        <int>[702, 703],
      );
    });

    test('in parallelen Bloecken von hoechstens 200 IDs', () async {
      final personen = <HitobitoPersonResource>[
        for (var id = 1; id <= 450; id++)
          HitobitoPersonResource(
            id: id,
            firstName: 'Person',
            lastName: '$id',
            membershipNumber: 10000 + id,
            primaryGroupId: 201,
            roles: <HitobitoPersonRoleResource>[
              HitobitoPersonRoleResource(
                id: 5000 + id,
                personId: id,
                groupId: 101,
              ),
            ],
          ),
      ];
      final peopleService = _FakeHitobitoPeopleService(people: personen);
      final rolesService = _FakeHitobitoRolesService(
        roles: <HitobitoPersonRoleResource>[
          for (final person in personen) ...person.roles,
        ],
      );
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(groups: gruppen),
        peopleService: peopleService,
        rolesService: rolesService,
        localRepository: _FakeArbeitskontextLocalRepository(),
      );

      final readModel = await repository.refresh(
        accessToken: 'token-123',
        arbeitskontext: arbeitskontext,
      );

      final idBloecke = peopleService.requestedFilters
          .where((filter) => filter.containsKey('filter[id]'))
          .map((filter) => filter['filter[id]']!.split(',').length);
      expect(idBloecke, <int>[200, 200, 50]);
      final rollenBloecke = rolesService.requestedFilters
          .where((filter) => filter.containsKey('filter[person_id]'))
          .map((filter) => filter['filter[person_id]']!.split(',').length);
      expect(rollenBloecke, <int>[200, 200, 50]);
      expect(readModel.mitglieder, hasLength(450));
      expect(readModel.rolesSindGeladen, isTrue);
    });

    test('laedt EFZ und Qualifikationen nur fuer Personen des Layers, in '
        'Bloecken von hoechstens 200 IDs (A-09)', () async {
      final personen = <HitobitoPersonResource>[
        for (var id = 1; id <= 450; id++)
          HitobitoPersonResource(
            id: id,
            firstName: 'Person',
            lastName: '$id',
            membershipNumber: 10000 + id,
            primaryGroupId: 101,
          ),
      ];
      // Lesbar, aber ausserhalb des Layers: darf nicht angefragt werden.
      const fremdePersonId = 9999;
      final efzService = _FakeHitobitoEfzService(
        eintraege: <EfzEinsichtnahme>[
          for (final person in personen)
            EfzEinsichtnahme(
              id: person.id,
              personId: person.id,
              issuedOn: DateTime(2024),
            ),
          EfzEinsichtnahme(
            id: fremdePersonId,
            personId: fremdePersonId,
            issuedOn: DateTime(2024),
          ),
        ],
      );
      final qualificationsService = _FakeHitobitoQualificationsService(
        eintraege: <Qualifikation>[
          for (final person in personen)
            Qualifikation(id: person.id, personId: person.id, label: 'Juleica'),
        ],
      );
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(groups: gruppen),
        peopleService: _FakeHitobitoPeopleService(people: personen),
        rolesService: _FakeHitobitoRolesService(),
        efzService: efzService,
        qualificationsService: qualificationsService,
        localRepository: _FakeArbeitskontextLocalRepository(),
      );

      final readModel = await repository.refresh(
        accessToken: 'token-123',
        arbeitskontext: arbeitskontext,
      );

      for (final filters in <List<Map<String, String>>>[
        efzService.requestedFilters,
        qualificationsService.requestedFilters,
      ]) {
        final bloecke = filters
            .map((filter) => filter['filter[person_id]']!.split(','))
            .toList();
        expect(bloecke.map((block) => block.length), <int>[200, 200, 50]);
        expect(bloecke.expand((block) => block).toSet(), <String>{
          for (final person in personen) '${person.id}',
        });
      }
      expect(readModel.efzEinsichtnahmen, hasLength(450));
      expect(readModel.qualifikationen, hasLength(450));
    });

    test('scheitert ohne Cache-Ueberschreibung, wenn die Rollen des Layers '
        'nicht geladen werden koennen', () async {
      final localRepository = _FakeArbeitskontextLocalRepository();
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(groups: gruppen),
        peopleService: _FakeHitobitoPeopleService(
          people: const <HitobitoPersonResource>[
            HitobitoPersonResource(
              id: 1,
              firstName: 'Julia',
              lastName: 'Keller',
              membershipNumber: 1001,
              primaryGroupId: 11,
            ),
          ],
        ),
        rolesService: _FakeHitobitoRolesService(
          error: const HitobitoRolesException('Rollen nicht erreichbar'),
          errorNurBeiFilter: 'filter[group_id]',
        ),
        localRepository: localRepository,
      );

      await expectLater(
        repository.refresh(
          accessToken: 'token-123',
          arbeitskontext: arbeitskontext,
        ),
        throwsA(isA<HitobitoRolesException>()),
      );
      expect(localRepository.saved, isNull);
    });
  });

  test(
    'refresh merkt sich die Gruppen der Layer oberhalb des aktiven Layers',
    () async {
      final repository = HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 1,
              name: 'Dioezese',
              isLayer: true,
              layerGroupId: 1,
            ),
            HitobitoGroupResource(
              id: 20,
              name: 'Bezirk Rhein',
              isLayer: true,
              parentId: 1,
              layerGroupId: 20,
            ),
            HitobitoGroupResource(
              id: 201,
              name: 'Bezirksleitung',
              isLayer: false,
              parentId: 20,
              layerGroupId: 20,
            ),
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              parentId: 20,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 101,
              name: 'Meute',
              isLayer: false,
              parentId: 11,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 12,
              name: 'Stamm Nachbar',
              isLayer: true,
              parentId: 20,
              layerGroupId: 12,
            ),
            HitobitoGroupResource(
              id: 121,
              name: 'Stammesleitung Nachbar',
              isLayer: false,
              parentId: 12,
              layerGroupId: 12,
            ),
          ],
        ),
        peopleService: _FakeHitobitoPeopleService(
          people: const <HitobitoPersonResource>[],
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

      // Dioezese und Bezirk samt Bezirksleitung, nicht aber der Nachbarstamm.
      expect(readModel.uebergeordneteGruppenIds, <int>{1, 20, 201});
    },
  );

  group('EFZ und Qualifikationen im refresh', () {
    const stamm = ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf');
    HitobitoArbeitskontextReadModelRepository repositoryMit({
      required _FakeHitobitoEfzService efzService,
      required _FakeHitobitoQualificationsService qualificationsService,
      _FakeArbeitskontextLocalRepository? localRepository,
    }) {
      return HitobitoArbeitskontextReadModelRepository(
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              layerGroupId: 11,
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
              primaryGroupId: 11,
            ),
          ],
        ),
        efzService: efzService,
        qualificationsService: qualificationsService,
        localRepository:
            localRepository ?? _FakeArbeitskontextLocalRepository(),
      );
    }

    test('speichert nur Eintraege der Personen im Kontext', () async {
      final efzService = _FakeHitobitoEfzService(
        eintraege: <EfzEinsichtnahme>[
          EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2024)),
          EfzEinsichtnahme(id: 2, personId: 99, issuedOn: DateTime(2024)),
        ],
      );
      final repository = repositoryMit(
        efzService: efzService,
        qualificationsService: _FakeHitobitoQualificationsService(
          eintraege: const <Qualifikation>[
            Qualifikation(id: 3, personId: 1, label: 'Woodbadge'),
            Qualifikation(id: 4, personId: 99, label: 'Juleica'),
          ],
        ),
      );

      final readModel = await repository.refresh(
        accessToken: 'token',
        arbeitskontext: Arbeitskontext(aktiverLayer: stamm),
      );

      expect(readModel.efzStand, TeildatenStand.geladen);
      expect(readModel.efzEinsichtnahmen.map((e) => e.id), <int>[1]);
      expect(efzService.requestedFilters, <Map<String, String>>[
        <String, String>{'filter[person_id]': '1'},
      ]);
      expect(readModel.qualifikationenStand, TeildatenStand.geladen);
      expect(readModel.findeQualifikationen(1).single.label, 'Woodbadge');
    });

    test(
      'wertet 403 als fehlende Berechtigung, nicht als Sync-Fehler',
      () async {
        final repository = repositoryMit(
          efzService: _FakeHitobitoEfzService(
            error: const HitobitoEfzException('verboten', statusCode: 403),
          ),
          qualificationsService: _FakeHitobitoQualificationsService(
            error: const HitobitoQualificationsException(
              'kaputt',
              statusCode: 500,
            ),
          ),
        );

        final readModel = await repository.refresh(
          accessToken: 'token',
          arbeitskontext: Arbeitskontext(aktiverLayer: stamm),
        );

        expect(readModel.efzStand, TeildatenStand.keineBerechtigung);
        expect(readModel.qualifikationenStand, TeildatenStand.fehlgeschlagen);
        expect(readModel.findeMitglied('1001'), isNotNull);
      },
    );

    test(
      'behaelt bei einem Fehlschlag den zuletzt geladenen Bestand',
      () async {
        final vorher = ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(aktiverLayer: stamm),
          efzStand: TeildatenStand.geladen,
          efzEinsichtnahmen: <EfzEinsichtnahme>[
            EfzEinsichtnahme(id: 7, personId: 1, issuedOn: DateTime(2023)),
          ],
        );
        final repository = repositoryMit(
          efzService: _FakeHitobitoEfzService(error: Exception('offline')),
          qualificationsService: _FakeHitobitoQualificationsService(),
          localRepository: _FakeArbeitskontextLocalRepository(cached: vorher),
        );

        final readModel = await repository.refresh(
          accessToken: 'token',
          arbeitskontext: Arbeitskontext(aktiverLayer: stamm),
        );

        expect(readModel.efzStand, TeildatenStand.geladen);
        expect(readModel.efzEinsichtnahmen.single.id, 7);
      },
    );
  });
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
  int fetchCallCount = 0;

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async {
    fetchCallCount += 1;
    return _groups;
  }
}

class _FakeHitobitoPeopleService extends HitobitoPeopleService {
  _FakeHitobitoPeopleService({
    List<HitobitoPersonResource> people = const <HitobitoPersonResource>[],
    List<List<HitobitoPersonResource>>? pages,
  }) : _people = people,
       _pages = pages,
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
  final List<List<HitobitoPersonResource>>? _pages;
  final List<Map<String, String>> requestedFilters = <Map<String, String>>[];

  @override
  Future<List<HitobitoPersonResource>> fetchPeopleResources(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
    void Function(List<HitobitoPersonResource> loadedSoFar)? onPageLoaded,
  }) async {
    requestedFilters.add(filter);
    final pages = _pages ?? <List<HitobitoPersonResource>>[_people];
    final loaded = <HitobitoPersonResource>[];
    for (final page in pages) {
      loaded.addAll(
        page.where(
          (person) =>
              _passtZuFilter(filter, 'filter[id]', person.id) &&
              _passtZuFilter(
                filter,
                'filter[primary_group_id]',
                person.primaryGroupId,
              ),
        ),
      );
      onPageLoaded?.call(List.unmodifiable(loaded));
    }
    return loaded;
  }
}

/// Bildet die Graphiti-Listenfilter (`filter[x]=1,2,3`) der API nach.
bool _passtZuFilter(Map<String, String> filter, String key, int? value) {
  final werte = filter[key];
  if (werte == null) {
    return true;
  }
  return value != null && werte.split(',').contains('$value');
}

class _FakeHitobitoRolesService extends HitobitoRolesService {
  _FakeHitobitoRolesService({
    List<HitobitoPersonRoleResource> roles =
        const <HitobitoPersonRoleResource>[],
    this.error,
    this.errorNurBeiFilter,
  }) : _roles = roles,
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

  final List<HitobitoPersonRoleResource> _roles;
  final Object? error;
  // Wirft [error] nur fuer Requests mit diesem Filter-Key, sonst immer.
  final String? errorNurBeiFilter;
  int fetchCallCount = 0;
  final List<Map<String, String>> requestedFilters = <Map<String, String>>[];

  @override
  Future<List<HitobitoPersonRoleResource>> fetchRoleResources(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
    void Function(List<HitobitoPersonRoleResource> loadedSoFar)? onPageLoaded,
  }) async {
    fetchCallCount += 1;
    requestedFilters.add(filter);
    final error = this.error;
    final errorKey = errorNurBeiFilter;
    if (error != null && (errorKey == null || filter.containsKey(errorKey))) {
      throw error;
    }
    final roles = _roles
        .where(
          (role) =>
              _passtZuFilter(filter, 'filter[group_id]', role.groupId) &&
              _passtZuFilter(filter, 'filter[person_id]', role.personId),
        )
        .toList(growable: false);
    onPageLoaded?.call(roles);
    return roles;
  }
}

const _testAuthConfig = HitobitoAuthConfig(
  clientId: 'client',
  clientSecret: 'secret',
  authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
  tokenUrl: 'https://demo.hitobito.com/oauth/token',
  redirectUri: 'de.jlange.nami.app:/oauth/callback',
  scopeString: 'openid email',
  discoveryUrl: '',
  profileUrl: 'https://demo.hitobito.com/oauth/profile',
);

class _FakeHitobitoEfzService extends HitobitoEfzService {
  _FakeHitobitoEfzService({
    this.eintraege = const <EfzEinsichtnahme>[],
    this.error,
  }) : super(config: _testAuthConfig);

  final List<EfzEinsichtnahme> eintraege;
  final Object? error;
  final List<Map<String, String>> requestedFilters = <Map<String, String>>[];

  @override
  Future<List<EfzEinsichtnahme>> fetchEfzEinsichtnahmen(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
  }) async {
    requestedFilters.add(filter);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    final personIds = filter['filter[person_id]']?.split(',').toSet();
    return eintraege
        .where(
          (eintrag) =>
              personIds == null || personIds.contains('${eintrag.personId}'),
        )
        .toList();
  }
}

class _FakeHitobitoQualificationsService extends HitobitoQualificationsService {
  _FakeHitobitoQualificationsService({
    this.eintraege = const <Qualifikation>[],
    this.error,
  }) : super(config: _testAuthConfig);

  final List<Qualifikation> eintraege;
  final Object? error;
  final List<Map<String, String>> requestedFilters = <Map<String, String>>[];

  @override
  Future<List<Qualifikation>> fetchQualifikationen(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
  }) async {
    requestedFilters.add(filter);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    final personIds = filter['filter[person_id]']?.split(',').toSet();
    return eintraege
        .where(
          (eintrag) =>
              personIds == null || personIds.contains('${eintrag.personId}'),
        )
        .toList();
  }
}
