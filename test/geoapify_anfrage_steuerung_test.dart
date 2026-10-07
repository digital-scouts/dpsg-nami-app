import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/geoapify_anfrage_steuerung.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _treffer =
    '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":1,"confidence_street_level":1,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}';

void main() {
  final now = DateTime(2026, 6, 5, 12);
  var jetzt = now;
  late GeoapifyAnfrageSteuerung steuerung;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    jetzt = now;
    steuerung = GeoapifyAnfrageSteuerung(nowProvider: () => jetzt);
  });

  GeoapifyAddressMapService serviceMit(MockClient client) =>
      GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: client,
        steuerung: steuerung,
      );

  test('pausiert nach 429 ohne Retry-After eine Stunde', () async {
    var anfragen = 0;
    final service = serviceMit(
      MockClient((request) async {
        anfragen++;
        return http.Response('', 429);
      }),
    );

    final erstes = await service.resolveAddress('Musterweg 4, Koeln');
    final zweites = await service.resolveAddress('Lindenallee 2, Koeln');

    expect(erstes.rateLimited, isTrue);
    expect(erstes.technicalError, isTrue);
    expect(zweites.rateLimited, isTrue);
    expect(anfragen, 1);
    expect(await steuerung.pauseBis(), now.add(const Duration(hours: 1)));

    jetzt = now.add(const Duration(hours: 1, seconds: 1));
    expect(await steuerung.pauseBis(), isNull);
  });

  test('uebernimmt Retry-After in Sekunden', () async {
    final service = serviceMit(
      MockClient(
        (request) async => http.Response(
          '',
          429,
          headers: <String, String>{'retry-after': '120'},
        ),
      ),
    );

    await service.resolveAddress('Musterweg 4, Koeln');

    expect(await steuerung.pauseBis(), now.add(const Duration(minutes: 2)));
  });

  test('teilt gleichzeitige Anfragen fuer dieselbe Adresse', () async {
    var anfragen = 0;
    final antwort = Completer<http.Response>();
    final service = serviceMit(
      MockClient((request) {
        anfragen++;
        return antwort.future;
      }),
    );

    final erstes = service.resolveAddress('Musterweg 4, Koeln');
    final zweites = service.resolveAddress(' musterweg 4, koeln ');
    await Future<void>.delayed(Duration.zero);
    antwort.complete(http.Response(_treffer, 200));

    expect((await erstes).location?.latitude, 53.5511);
    expect((await zweites).location?.latitude, 53.5511);
    expect(anfragen, 1);
  });
}
