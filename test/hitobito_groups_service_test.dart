import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';

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
      expect(
        requestedUris.first.toString(),
        'https://demo.hitobito.com/api/groups',
      );
      expect(
        requestedUris.last.toString(),
        'https://demo.hitobito.com/api/groups?page=2',
      );
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
      expect(groups.last.createdAt, DateTime.parse('2026-04-10T05:00:29+02:00'));
      expect(groups.last.updatedAt, DateTime.parse('2026-04-11T02:45:44+02:00'));
    },
  );
}
