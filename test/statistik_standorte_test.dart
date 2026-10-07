import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/domain/maps/address_map_location.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/statistics/statistik_standorte.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/geoapify_anfrage_steuerung.dart';
import 'package:nami/services/statistics_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _treffer =
    '{"results":[{"lat":50.9,"lon":6.9,"rank":{"confidence":1,"confidence_street_level":1,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'nachgeladene Stammadresse fragt Mitgliedsadressen nicht doppelt an',
    (tester) async {
      final angefragt = <String>[];
      final ersteAntwort = Completer<http.Response>();
      final service = StatisticsLocationService(
        repository: _InMemoryRepository(),
        anfrageAbstand: Duration.zero,
        fehlerSperreBis: <String, DateTime>{},
        mapService: GeoapifyAddressMapService(
          apiKeyOverride: 'test-key',
          steuerung: GeoapifyAnfrageSteuerung(),
          httpClient: MockClient((request) {
            angefragt.add(request.url.queryParameters['text']!);
            if (angefragt.length == 1) {
              return ersteAntwort.future;
            }
            return Future.value(http.Response(_treffer, 200));
          }),
        ),
      );
      final mitglieder = <Mitglied>[
        _mitglied('1', 'Musterweg'),
        _mitglied('2', 'Lindenallee'),
      ];

      Widget kachel(String? stammAddress) => MaterialApp(
        home: StatistikStandortAufloesung(
          members: mitglieder,
          stammAddress: stammAddress,
          service: service,
          builder: (context, daten) =>
              Text(daten == null ? 'laedt' : '${daten.memberPoints.length}'),
        ),
      );

      await tester.pumpWidget(kachel(null));
      await tester.pump();
      await tester.pumpWidget(kachel('Heimweg 1, 50667 Koeln'));
      await tester.pump();
      ersteAntwort.complete(http.Response(_treffer, 200));
      await tester.pumpAndSettle();

      expect(angefragt, <String>[
        'Musterweg 4, 50667 Koeln',
        'Lindenallee 4, 50667 Koeln',
        'Heimweg 1, 50667 Koeln',
      ]);
    },
  );
}

Mitglied _mitglied(String nummer, String strasse) => Mitglied.peopleListItem(
  mitgliedsnummer: nummer,
  vorname: 'Mara',
  nachname: 'Muster',
  adressen: <MitgliedKontaktAdresse>[
    MitgliedKontaktAdresse(
      additionalAddressId: 0,
      street: strasse,
      housenumber: '4',
      zipCode: '50667',
      town: 'Koeln',
    ),
  ],
);

class _InMemoryRepository implements AddressMapLocationRepository {
  final Map<String, AddressMapLocation> _eintraege =
      <String, AddressMapLocation>{};

  @override
  Future<void> clearAll() async => _eintraege.clear();

  @override
  Future<int> countEntries() async => _eintraege.length;

  @override
  Future<AddressMapLocation?> load(String cacheKey) async =>
      _eintraege[cacheKey];

  @override
  Future<void> remove(String cacheKey) async => _eintraege.remove(cacheKey);

  @override
  Future<void> save(AddressMapLocation location) async =>
      _eintraege[location.cacheKey] = location;
}
