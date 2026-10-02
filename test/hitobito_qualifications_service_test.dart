import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_qualifications_service.dart';

void main() {
  HitobitoQualificationsService serviceMit(MockClient client) =>
      HitobitoQualificationsService(
        config: HitobitoAuthConfig.fromBaseUrl(
          clientId: 'client',
          clientSecret: 'secret',
          baseUrl: 'https://demo.hitobito.com',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
        ),
        httpClient: client,
      );

  test('laedt Qualifikationen mit Art ueber alle Seiten', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      final seite2 = request.url.queryParameters['page'] == '2';
      return http.Response(
        seite2
            ? '''
            {
              "data": [
                {
                  "id": "12", "type": "qualifications",
                  "attributes": { "person_id": 24, "qualification_kind_id": 7, "qualified_at": "2019-06-10" }
                }
              ],
              "included": [
                { "id": "7", "type": "qualification_kinds", "attributes": { "label": "Woodbadge", "validity": null, "reactivateable": null } }
              ],
              "links": { "next": null }
            }
            '''
            : '''
            {
              "data": [
                {
                  "id": "11", "type": "qualifications",
                  "attributes": { "person_id": 23, "start_at": "2020-05-01", "finish_at": "2023-05-01", "origin": "Kurs" },
                  "relationships": { "qualification_kind": { "data": { "id": "5", "type": "qualification_kinds" } } }
                },
                {
                  "id": "13", "type": "qualifications",
                  "attributes": { "person_id": 23, "qualification_kind_id": 99 }
                }
              ],
              "included": [
                { "id": "5", "type": "qualification_kinds", "attributes": { "label": "Juleica", "validity": 3, "reactivateable": 2 } }
              ],
              "links": { "next": "/api/qualifications?page=2" }
            }
            ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final qualifikationen = await serviceMit(
      client,
    ).fetchAlleQualifikationen('token-123');

    // Eintrag 13 verweist auf eine unbekannte Art und wird uebersprungen.
    expect(qualifikationen.map((q) => q.id), <int>[11, 12]);
    final juleica = qualifikationen.first;
    expect(juleica.label, 'Juleica');
    expect(juleica.personId, 23);
    expect(juleica.artId, 5);
    expect(juleica.finishAt, DateTime(2023, 5, 1));
    expect(juleica.erworbenAm, DateTime(2020, 5, 1));
    expect(juleica.reaktivierbar, isTrue);
    expect(juleica.gueltigkeitJahre, 3);
    final woodbadge = qualifikationen.last;
    expect(woodbadge.label, 'Woodbadge');
    expect(woodbadge.finishAt, isNull);
    expect(woodbadge.reaktivierbar, isFalse);
    expect(woodbadge.gueltigkeitJahre, isNull);

    expect(requestedUris.first.path, '/api/qualifications');
    expect(
      requestedUris.first.queryParameters['include'],
      'qualification_kind',
    );
    expect(requestedUris.last.queryParameters['page'], '2');
  });

  test('wirft bei fehlender Berechtigung mit Statuscode 403', () async {
    final client = MockClient(
      (request) async => http.Response('{"errors":[]}', 403),
    );

    await expectLater(
      serviceMit(client).fetchAlleQualifikationen('token'),
      throwsA(
        isA<HitobitoQualificationsException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });
}
