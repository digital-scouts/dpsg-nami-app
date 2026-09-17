import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_efz_service.dart';

HitobitoAuthConfig _testConfig() => HitobitoAuthConfig.fromBaseUrl(
  clientId: 'client',
  clientSecret: 'secret',
  baseUrl: 'https://demo.hitobito.com',
  redirectUri: 'de.jlange.nami.app:/oauth/callback',
  scopeString: 'openid email',
);

void main() {
  test(
    'laedt Efz-Einsichtnahmen einer Person mit person_id-Filter und Sortierung',
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
                "id": "96",
                "type": "efz_einsichtnahmen",
                "attributes": {
                  "person_id": 23,
                  "einsichtnehmer_id": 5,
                  "einsicht_on": "2021-03-01",
                  "issued_on": "2021-02-15"
                }
              }
            ],
            "links": { "next": null }
          }
          ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = HitobitoEfzService(
        config: _testConfig(),
        httpClient: client,
      );
      final result = await service.fetchEfzEinsichtnahmenFuerPerson(
        'token-123',
        personId: 23,
      );

      expect(result, hasLength(1));
      expect(result.first.id, 96);
      expect(result.first.personId, 23);
      expect(result.first.einsichtnehmerId, 5);
      expect(result.first.einsichtOn, DateTime(2021, 3, 1));
      expect(result.first.issuedOn, DateTime(2021, 2, 15));

      expect(requestedUris, hasLength(1));
      expect(
        requestedUris.single.queryParameters['filter[person_id][eq]'],
        '23',
      );
      expect(requestedUris.single.queryParameters['sort'], '-issued_on');
      expect(requestHeaders['Authorization'], 'Bearer token-123');
    },
  );

  test('folgt Pagination-Links beim Laden aller Efz-Einsichtnahmen', () async {
    final requestedUris = <Uri>[];

    final client = MockClient((request) async {
      requestedUris.add(request.url);

      if (request.url.queryParameters['page[number]'] == '2') {
        return http.Response(
          '''
          {
            "data": [
              {
                "id": "2",
                "type": "efz_einsichtnahmen",
                "attributes": { "person_id": 24, "issued_on": "2020-01-01" }
              }
            ],
            "links": { "next": null }
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
              "id": "1",
              "type": "efz_einsichtnahmen",
              "attributes": { "person_id": 23, "issued_on": "2021-01-01" }
            }
          ],
          "links": {
            "next": "https://demo.hitobito.com/api/efz_einsichtnahmen?page[number]=2"
          }
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final service = HitobitoEfzService(
      config: _testConfig(),
      httpClient: client,
    );
    final result = await service.fetchAlleEfzEinsichtnahmen('token-123');

    expect(result, hasLength(2));
    expect(requestedUris, hasLength(2));
  });

  test(
    'liefert die PDF-Bytes des Efz-Antrags bei erfolgreicher Antwort',
    () async {
      Uri? requestedUri;
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUri = request.url;
        requestHeaders = request.headers;
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: <String, String>{'content-type': 'application/pdf'},
        );
      });

      final service = HitobitoEfzService(
        config: _testConfig(),
        httpClient: client,
      );
      final bytes = await service.downloadEfzAntrag(
        'token-123',
        groupId: 68,
        personId: 375,
      );

      expect(bytes, <int>[1, 2, 3]);
      expect(requestedUri?.path, '/groups/68/people/375/efz_antrag');
      expect(requestHeaders['Authorization'], 'Bearer token-123');
    },
  );

  test(
    'wirft HitobitoEfzAntragUnavailableException, wenn kein PDF geliefert wird',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html>Login required</html>',
          302,
          headers: <String, String>{'content-type': 'text/html'},
        );
      });

      final service = HitobitoEfzService(
        config: _testConfig(),
        httpClient: client,
      );

      expect(
        () =>
            service.downloadEfzAntrag('token-123', groupId: 68, personId: 375),
        throwsA(isA<HitobitoEfzAntragUnavailableException>()),
      );
    },
  );
}
