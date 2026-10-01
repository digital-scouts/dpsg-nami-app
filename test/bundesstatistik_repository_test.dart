import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/data/bundesstatistik/http_bundesstatistik_repository.dart';
import 'package:nami/domain/bundesstatistik/bundesaggregat.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_repository.dart';
import 'package:nami/domain/bundesstatistik/installation_credentials.dart';
import 'package:nami/domain/bundesstatistik/stammes_snapshot.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

const _credentials = InstallationCredentials(id: 'install-1', secret: 'geheim');

StammesSnapshot _snapshot() => StammesSnapshot(
  stammId: '11',
  senderId: 'install-1',
  sentAt: DateTime.utc(2026, 6, 15, 10),
  sourceDataAsOf: DateTime.utc(2026, 6, 15, 9),
  kennzahlen: const StammesKennzahlen(
    aktiveMitglieder: 3,
    biber: GeschlechterVerteilung.leer(),
    woelflinge: GeschlechterVerteilung(
      gesamt: 3,
      maennlich: 1,
      weiblich: 2,
      divers: 0,
      geschlechtUnbekannt: 0,
    ),
    jungpfadfinder: GeschlechterVerteilung.leer(),
    pfadfinder: GeschlechterVerteilung.leer(),
    rover: GeschlechterVerteilung.leer(),
    leitende: LeitendeAltersVerteilung(
      gesamt: 1,
      unter21: 0,
      von21Bis30: 1,
      von31Bis40: 0,
      von41Bis50: 0,
      von51Bis60: 0,
      ueber60: 0,
    ),
    leitendeBiber: GeschlechterVerteilung.leer(),
    leitendeWoelflinge: GeschlechterVerteilung.leer(),
    leitendeJungpfadfinder: GeschlechterVerteilung.leer(),
    leitendePfadfinder: GeschlechterVerteilung.leer(),
    leitendeRover: GeschlechterVerteilung.leer(),
    nichtLeitendeErwachsene: 0,
    gruppen: <GruppenKennzahl>[
      GruppenKennzahl(
        gruppenId: 21,
        stufe: Stufe.woelfling,
        abgedeckt: true,
        mitglieder: GeschlechterVerteilung(
          gesamt: 3,
          maennlich: 1,
          weiblich: 2,
          divers: 0,
          geschlechtUnbekannt: 0,
        ),
        leitende: GeschlechterVerteilung.leer(),
      ),
    ],
  ),
);

http.Response _error(int status, String code) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': 'x'},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('sendet den Snapshot als JSON mit Bearer-Secret', () async {
    late http.Request captured;
    final repository = HttpBundesstatistikRepository(
      baseUrl: 'https://stats.example.org',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await repository.sendeSnapshot(_snapshot(), _credentials);

    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://stats.example.org/snapshots/stamm',
    );
    expect(captured.headers['authorization'], 'Bearer geheim');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['schema_version'], '2026-10-01');
    expect(body['sender_id'], 'install-1');
    expect(body['abdeckung'], 'stamm');
    expect(body['gruppen'], [
      {
        'gruppe_id': '21',
        'stufe': 'woelflinge',
        'abgedeckt': true,
        'mitglieder': {
          'gesamt': 3,
          'maennlich': 1,
          'weiblich': 2,
          'divers': 0,
          'geschlecht_unbekannt': 0,
        },
        'leitende': {
          'gesamt': 0,
          'maennlich': 0,
          'weiblich': 0,
          'divers': 0,
          'geschlecht_unbekannt': 0,
        },
      },
    ]);
    expect((body['metrics'] as Map)['leitende']['gesamt'], 1);
    expect((body['metrics'] as Map).containsKey('woelflinge'), isFalse);
  });

  test('bildet Fehlerantworten auf Fehlerarten ab', () async {
    final cases = <http.Response, BundesstatistikFehlerArt>{
      _error(401, 'invalid_sender_credentials'):
          BundesstatistikFehlerArt.ungueltigeCredentials,
      _error(403, 'not_participating'):
          BundesstatistikFehlerArt.nichtTeilnehmend,
      _error(429, 'rate_limited'): BundesstatistikFehlerArt.zuVieleAnfragen,
      _error(400, 'invalid_stamm_plausibility'):
          BundesstatistikFehlerArt.abgelehnt,
      http.Response('Bad Gateway', 502): BundesstatistikFehlerArt.unbekannt,
    };

    for (final entry in cases.entries) {
      final repository = HttpBundesstatistikRepository(
        baseUrl: 'https://stats.example.org/',
        httpClient: MockClient((_) async => entry.key),
      );
      await expectLater(
        repository.sendeSnapshot(_snapshot(), _credentials),
        throwsA(
          isA<BundesstatistikException>().having(
            (e) => e.art,
            'art',
            entry.value,
          ),
        ),
      );
    }
  });

  test('meldet Netzwerkfehler als netzwerk', () async {
    final repository = HttpBundesstatistikRepository(
      baseUrl: 'https://stats.example.org',
      httpClient: MockClient(
        (_) async => throw http.ClientException('offline'),
      ),
    );

    await expectLater(
      repository.ladeBundesaggregat(_credentials),
      throwsA(
        isA<BundesstatistikException>().having(
          (e) => e.art,
          'art',
          BundesstatistikFehlerArt.netzwerk,
        ),
      ),
    );
  });

  test('laedt und flacht das Bundesaggregat ab', () async {
    late http.Request captured;
    final repository = HttpBundesstatistikRepository(
      baseUrl: 'https://stats.example.org',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 'ok',
              'aggregation_type': 'bund',
              'aggregation_week': '2026-W24',
              'generated_at': '2026-06-15T10:00:00.000Z',
              'participating_stamm_count': 12,
              'min_stamm_count': 5,
              'data_as_of': {
                'oldest': '2026-05-01T00:00:00.000Z',
                'newest': '2026-06-15T09:00:00.000Z',
              },
              'notice': 'Annäherung',
              'metrics': {
                'woelflinge': {
                  'gesamt': {'sum': 120, 'stamm_count': 12, 'median': 9.5},
                  'divers': {'sum': null, 'stamm_count': 2, 'median': null},
                },
                'kuraten': {'sum': null, 'stamm_count': 0, 'median': null},
              },
              'gruppen_je_stufe': {
                'woelflinge': {
                  'gruppen_count': 15,
                  'stamm_count': 12,
                  'gruppen_pro_stamm': {
                    'sum': 15,
                    'stamm_count': 12,
                    'median': 1,
                  },
                  'mitglieder': {
                    'gesamt': {
                      'sum': 150,
                      'stamm_count': 12,
                      'gruppen_count': 15,
                      'median': 9,
                    },
                  },
                  'leitende': {
                    'gesamt': {
                      'sum': null,
                      'stamm_count': 3,
                      'gruppen_count': 4,
                      'median': null,
                    },
                  },
                },
              },
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final aggregat = await repository.ladeBundesaggregat(_credentials);

    expect(captured.url.path, '/aggregates/bund/latest');
    expect(captured.headers['x-sender-id'], 'install-1');
    expect(captured.headers['authorization'], 'Bearer geheim');
    expect(aggregat.status, BundesaggregatStatus.ok);
    expect(aggregat.teilnehmendeStaemme, 12);
    expect(aggregat.hinweis, 'Annäherung');
    expect(aggregat.datenstandBis, DateTime.utc(2026, 6, 15, 9));
    final woelflinge = aggregat.kennzahl('woelflinge.gesamt')!;
    expect(woelflinge.median, 9.5);
    expect(woelflinge.durchschnitt, 10);
    expect(aggregat.kennzahl('woelflinge.divers')!.istUnterdrueckt, isTrue);
    expect(aggregat.kennzahl('kuraten')!.stammAnzahl, 0);
    final meuten = aggregat.gruppenDerStufe('woelflinge')!;
    expect(meuten.gruppenAnzahl, 15);
    expect(meuten.gruppenProStamm.median, 1);
    expect(meuten.mitglieder['gesamt']!.median, 9);
    // Durchschnitt je Gruppe, nicht je Stamm.
    expect(meuten.mitglieder['gesamt']!.durchschnitt, 10);
    expect(meuten.leitende['gesamt']!.istUnterdrueckt, isTrue);
    expect(aggregat.gruppenDerStufe('rover'), isNull);
  });
}
