import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_people_service.dart';

void main() {
  test(
    'laedt /api/people und mappt Vor- und Nachnamen auf Mitglied',
    () async {
      late Uri requestedUri;
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUri = request.url;
        requestHeaders = request.headers;
        return http.Response(
          '''
        {
          "data": [
            {
              "id": "23",
              "type": "people",
              "attributes": {
                "first_name": "Julia",
                "last_name": "Keller",
                "nickname": "Polka",
                "membership_number": 1001
              }
            }
          ]
        }
        ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = HitobitoPeopleService(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
        httpClient: client,
      );

      final people = await service.fetchPeople('token-123');

      expect(requestedUri.toString(), 'https://demo.hitobito.com/api/people');
      expect(requestHeaders['Authorization'], 'Bearer token-123');
      expect(people, hasLength(1));
      expect(people.single.vorname, 'Julia');
      expect(people.single.nachname, 'Keller');
      expect(people.single.fahrtenname, 'Polka');
      expect(people.single.mitgliedsnummer, '1001');
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}
