import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_roles_service.dart';

void main() {
  test(
    'laedt Rollen ohne ungueltigen active-Filter und behaelt bestehende Query-Parameter',
    () async {
      final requestedUris = <Uri>[];
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        requestHeaders = request.headers;

        return http.Response(
          '''
          {
            "data": [
              {
                "id": "701",
                "type": "roles",
                "attributes": {
                  "person_id": 23,
                  "group_id": 11,
                  "created_at": "2024-01-01T09:00:00Z",
                  "updated_at": "2024-02-01T09:00:00Z",
                  "start_on": "2020-01-01",
                  "end_on": "2021-01-01",
                  "type": "Group::Mitglied",
                  "label": "Mitglied",
                  "name": "Mitglied"
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
      });

      final service = HitobitoRolesService(
        config: HitobitoAuthConfig.fromBaseUrl(
          clientId: 'client',
          clientSecret: 'secret',
          baseUrl: 'https://demo.hitobito.com',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
        ),
        httpClient: client,
      );

      final roles = await service.fetchRoleResources('token-123');

      expect(roles, hasLength(1));
      expect(roles.first.id, 701);
      expect(roles.first.personId, 23);
      expect(roles.first.groupId, 11);
      expect(roles.first.startOn, DateTime(2020, 1, 1));
      expect(roles.first.endOn, DateTime(2021, 1, 1));

      expect(requestedUris, hasLength(1));
      expect(
        requestedUris.single.queryParameters['fields[roles]'],
        'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label',
      );
      expect(
        requestedUris.single.queryParameters.containsKey('filter[active][eq]'),
        isFalse,
      );
      expect(requestHeaders['Authorization'], 'Bearer token-123');
      expect(
        requestHeaders['Accept'],
        'application/vnd.api+json, application/json',
      );
      expect(
        requestedUris.single.queryParameters['include'],
        'group,layer_group',
      );
      expect(requestedUris.single.queryParameters['fields[groups]'], 'name');
    },
  );

  test('folgt Pagination-Links mit dekorierten Folgeanfragen', () async {
    final requestedUris = <Uri>[];

    final client = MockClient((request) async {
      requestedUris.add(request.url);

      if (request.url.queryParameters['page[number]'] == '2') {
        return http.Response(
          '''
          {
            "data": [
              {
                "id": "702",
                "type": "roles",
                "attributes": {
                  "person_id": 23,
                  "group_id": 12,
                  "type": "Group::Leiter",
                  "label": "Leitung",
                  "name": "Leitung"
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
              "id": "701",
              "type": "roles",
              "attributes": {
                "person_id": 23,
                "group_id": 11,
                "type": "Group::Mitglied",
                "label": "Mitglied",
                "name": "Mitglied"
              }
            }
          ],
          "links": {
            "next": "https://demo.hitobito.com/api/roles?page[number]=2"
          }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final service = HitobitoRolesService(
      config: HitobitoAuthConfig.fromBaseUrl(
        clientId: 'client',
        clientSecret: 'secret',
        baseUrl: 'https://demo.hitobito.com',
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
        scopeString: 'openid email',
      ),
      httpClient: client,
    );

    final roles = await service.fetchRoleResources('token-123');

    expect(roles, hasLength(2));
    expect(requestedUris, hasLength(2));
    expect(requestedUris.last.queryParameters['page[number]'], '2');
    expect(
      requestedUris.last.queryParameters['fields[roles]'],
      'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label',
    );
    expect(
      requestedUris.last.queryParameters.containsKey('filter[active][eq]'),
      isFalse,
    );
  });

  HitobitoRolesService serviceMit(MockClient client) => HitobitoRolesService(
    config: HitobitoAuthConfig.fromBaseUrl(
      clientId: 'client',
      clientSecret: 'secret',
      baseUrl: 'https://demo.hitobito.com',
      redirectUri: 'de.jlange.nami.app:/oauth/callback',
      scopeString: 'openid email',
    ),
    httpClient: client,
  );

  test('liest Gruppen- und Layernamen aus included', () async {
    final client = MockClient((request) async {
      return http.Response(
        '''
        {
          "data": [
            {
              "id": "801",
              "type": "roles",
              "attributes": { "person_id": 23, "group_id": 90, "type": "Group::Bezirk::Mitarbeiter" },
              "relationships": {
                "group": { "data": { "id": "90", "type": "groups" } },
                "layer_group": { "data": { "id": "9", "type": "groups" } }
              }
            }
          ],
          "included": [
            { "id": "90", "type": "groups", "attributes": { "name": "AK Wölflingsstufe" } },
            { "id": "9", "type": "groups", "attributes": { "name": "Bezirk Rheinauen" } }
          ],
          "links": { "next": null }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final roles = await serviceMit(client).fetchRoleResources('token');

    expect(roles.single.groupName, 'AK Wölflingsstufe');
    expect(roles.single.layerName, 'Bezirk Rheinauen');
  });

  test(
    'laedt ohne Gruppen-Sideloads weiter, wenn die Instanz sie ablehnt',
    () async {
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.queryParameters.containsKey('include')) {
          return http.Response('{"errors":[]}', 400);
        }
        return http.Response(
          '''
        {
          "data": [
            { "id": "802", "type": "roles", "attributes": { "person_id": 23, "group_id": 11 } }
          ],
          "links": { "next": null }
        }
        ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final roles = await serviceMit(client).fetchRoleResources('token');

      expect(roles.single.id, 802);
      expect(roles.single.groupName, isNull);
      expect(requestedUris, hasLength(2));
      expect(
        requestedUris.last.queryParameters.containsKey('include'),
        isFalse,
      );
    },
  );
}
