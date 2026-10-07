import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';

import 'support/fake_graphiti_list_api.dart';

void main() {
  test(
    'laedt accessible groups ueber /api/groups und mappt Layer-Felder',
    () async {
      final requestedUris = <Uri>[];
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        requestHeaders = request.headers;

        if (request.url.queryParameters['page'] == '2') {
          return http.Response(
            '''
        {
          "data": [
            {
              "id": "101",
              "attributes": {
                "name": "Woelflinge",
                "layer": false,
                "parent_id": 11,
                "layer_group_id": 11,
                "display_name": "Fuechse",
                "short_name": "F",
                "description": "Wolfsstufe",
                "type": "Group::Meute",
                "self_registration_url": "https://demo.hitobito.com/de/groups/101/self_registration",
                "self_registration_require_adult_consent": false,
                "archived_at": null,
                "created_at": "2026-04-10T05:00:29+02:00",
                "updated_at": "2026-04-11T02:45:44+02:00",
                "deleted_at": null
              }
            }
          ],
          "links": {
            "next": null
          }
        }
        ''',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response(
          '''
        {
          "data": [
            {
              "id": "11",
              "attributes": {
                "name": "Stamm Musterdorf",
                "layer": true,
                "parent_id": 5,
                "layer_group_id": 11
              }
            }
          ],
          "links": {
            "next": "https://demo.hitobito.com/api/groups?page=2"
          }
        }
        ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = HitobitoGroupsService(
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
        httpClient: client,
      );

      final groups = await service.fetchAccessibleGroups('token-123');

      expect(requestedUris, hasLength(2));
      expect(requestedUris.first.host, 'demo.hitobito.com');
      expect(requestedUris.first.path, '/api/groups');
      expect(requestedUris.first.queryParameters, {
        'page[size]': '1000',
        'sort': 'id',
        'fields[groups]': hitobitoGroupFields,
      });
      expect(requestedUris.last.queryParameters, {
        'page': '2',
        'page[size]': '1000',
        'sort': 'id',
        'fields[groups]': hitobitoGroupFields,
      });
      expect(requestHeaders['Authorization'], 'Bearer token-123');
      expect(groups, hasLength(2));
      expect(groups.first.isLayer, isTrue);
      expect(groups.first.parentId, 5);
      expect(groups.first.layerGroupId, 11);
      expect(groups.last.isLayer, isFalse);
      expect(groups.last.layerGroupId, 11);
      expect(groups.last.displayName, 'Fuechse');
      expect(groups.last.shortName, 'F');
      expect(groups.last.description, 'Wolfsstufe');
      expect(groups.last.groupType, 'Group::Meute');
      expect(
        groups.last.selfRegistrationUrl,
        'https://demo.hitobito.com/de/groups/101/self_registration',
      );
      expect(groups.last.selfRegistrationRequireAdultConsent, isFalse);
      expect(
        groups.last.createdAt,
        DateTime.parse('2026-04-10T05:00:29+02:00'),
      );
      expect(
        groups.last.updatedAt,
        DateTime.parse('2026-04-11T02:45:44+02:00'),
      );
    },
  );

  final config = HitobitoAuthConfig.fromBaseUrl(
    clientId: 'client',
    clientSecret: 'secret',
    baseUrl: 'https://demo.hitobito.com',
    redirectUri: 'de.jlange.nami.app:/oauth/callback',
    scopeString: 'openid email',
  );

  test('fragt nur die genutzten Felder an, damit ein ungueltiges anderes '
      'Attribut die Seite nicht scheitern laesst (A-14)', () async {
    final api = FakeGraphitiListApi()
      ..setze('groups', <GraphitiRecord>[
        for (var id = 1; id <= 1500; id++)
          GraphitiRecord(
            id: id,
            attributes: <String, dynamic>{
              'name': 'Gruppe $id',
              'layer': true,
              'zip_code': 12345,
              'iban': 'DE00 0000',
            },
          ),
      ])
      ..defekteGruppen[1200] = 'zip_code';

    final groups = await HitobitoGroupsService(
      config: config,
      httpClient: api.client,
    ).fetchAccessibleGroups('token-123');

    expect(groups, hasLength(1500));
    expect(api.requests, hasLength(2));
    for (final uri in api.requests) {
      expect(uri.queryParameters['fields[groups]'], hitobitoGroupFields);
    }
  });

  test('ueberspringt eine ungueltige Einzelgruppe statt abzubrechen', () async {
    final api = FakeGraphitiListApi()
      ..setze('groups', <GraphitiRecord>[
        const GraphitiRecord(
          id: 1,
          attributes: <String, dynamic>{'name': 'Stamm', 'layer': true},
        ),
        const GraphitiRecord(
          id: 2,
          attributes: <String, dynamic>{'name': '', 'layer': false},
        ),
      ]);

    final groups = await HitobitoGroupsService(
      config: config,
      httpClient: api.client,
    ).fetchAccessibleGroups('token-123');

    expect(groups.map((group) => group.id), <int>[1]);
  });

  group('defekte Gruppenseite (A-14)', () {
    FakeGraphitiListApi instanzMitDefekterGruppe(String defektesFeld) {
      return FakeGraphitiListApi()
        ..setze('groups', <GraphitiRecord>[
          for (var id = 1; id <= 1500; id++)
            GraphitiRecord(
              id: id,
              attributes: <String, dynamic>{
                'name': 'Gruppe $id',
                'layer': true,
                'description': 'Beschreibung $id',
              },
            ),
        ])
        ..defekteGruppen[1200] = defektesFeld;
    }

    test('laedt um die defekte Gruppe herum und holt sie mit '
        'Minimalfeldern nach', () async {
      final api = instanzMitDefekterGruppe('description');

      final groups = await HitobitoGroupsService(
        config: config,
        httpClient: api.client,
      ).fetchAccessibleGroups('token-123');

      expect(groups, hasLength(1500));
      expect(groups.map((group) => group.id).toSet(), hasLength(1500));
      final defekt = groups.singleWhere((group) => group.id == 1200);
      expect(defekt.name, 'Gruppe 1200');
      expect(defekt.description, isNull);
      // 2 Seiten regulaer (Seite 2 scheitert), 2 ID-Seiten, 8 Bloecke,
      // 2 je Halbierungsstufe bis zur Einzelgruppe (200 -> 1: 8 Stufen) und
      // 1 Abruf mit Minimalfeldern.
      expect(api.requests, hasLength(2 + 2 + 8 + 16 + 1));
    });

    test('laesst eine auch mit Minimalfeldern defekte Gruppe aus', () async {
      final api = instanzMitDefekterGruppe('name');

      final groups = await HitobitoGroupsService(
        config: config,
        httpClient: api.client,
      ).fetchAccessibleGroups('token-123');

      expect(groups, hasLength(1499));
      expect(groups.any((group) => group.id == 1200), isFalse);
    });

    test('wirft bei 503 weiter statt zu halbieren', () async {
      final client = MockClient((request) async => http.Response('', 503));

      await expectLater(
        HitobitoGroupsService(
          config: config,
          httpClient: client,
        ).fetchAccessibleGroups('token-123'),
        throwsA(
          isA<HitobitoGroupsException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });
  });
}
