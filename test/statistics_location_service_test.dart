import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/maps/address_map_location.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/statistics_location_service.dart';

void main() {
  test('nutzt frischen Negativ-Cache ohne Geoapify-Aufruf', () async {
    final now = DateTime(2026, 6, 5, 12);
    final repository = _InMemoryAddressMapLocationRepository();
    final member = _memberWithAddress();
    final fingerprint = MemberAddressUtils.fingerprint(member.primaryAddress!);
    await repository.save(
      AddressMapLocation(
        cacheKey: fingerprint,
        resolvedAt: now.subtract(const Duration(days: 6)),
        addressFingerprint: fingerprint,
        addressNotFound: true,
      ),
    );
    final mapService = _FakeGeoapifyAddressMapService(
      const GeoapifyGeocodeResult.success(LatLng(53.5511, 9.9937)),
    );
    final service = StatisticsLocationService(
      repository: repository,
      mapService: mapService,
      negativeCacheTtl: const Duration(days: 7),
      nowProvider: () => now,
    );

    final points = await service.resolveMemberLocations(<Mitglied>[member]);

    expect(points, isEmpty);
    expect(mapService.calls, 0);
  });

  test('ignoriert abgelaufenen Negativ-Cache und geocodiert neu', () async {
    final now = DateTime(2026, 6, 5, 12);
    final repository = _InMemoryAddressMapLocationRepository();
    final member = _memberWithAddress();
    final fingerprint = MemberAddressUtils.fingerprint(member.primaryAddress!);
    await repository.save(
      AddressMapLocation(
        cacheKey: fingerprint,
        resolvedAt: now.subtract(const Duration(days: 8)),
        addressFingerprint: fingerprint,
        addressNotFound: true,
      ),
    );
    final mapService = _FakeGeoapifyAddressMapService(
      const GeoapifyGeocodeResult.success(LatLng(53.5511, 9.9937)),
    );
    final service = StatisticsLocationService(
      repository: repository,
      mapService: mapService,
      negativeCacheTtl: const Duration(days: 7),
      nowProvider: () => now,
    );

    final points = await service.resolveMemberLocations(<Mitglied>[member]);
    final cached = await repository.load(fingerprint);

    expect(points, hasLength(1));
    expect(points.single.latitude, 53.5511);
    expect(mapService.calls, 1);
    expect(cached?.addressNotFound, isFalse);
    expect(cached?.hasCoordinates, isTrue);
  });

  group('Lauf der Standorte-Kachel', () {
    final now = DateTime(2026, 6, 5, 12);
    late _InMemoryAddressMapLocationRepository repository;
    late Map<String, DateTime> fehlerSperre;

    setUp(() {
      repository = _InMemoryAddressMapLocationRepository();
      fehlerSperre = <String, DateTime>{};
    });

    StatisticsLocationService serviceMit(
      _FakeGeoapifyAddressMapService mapService, {
      DateTime Function()? nowProvider,
    }) => StatisticsLocationService(
      repository: repository,
      mapService: mapService,
      nowProvider: nowProvider ?? () => now,
      anfrageAbstand: Duration.zero,
      fehlerSperreBis: fehlerSperre,
    );

    final zweiMitglieder = <Mitglied>[
      _memberWithAddress(mitgliedsnummer: '1', street: 'Musterweg'),
      _memberWithAddress(mitgliedsnummer: '2', street: 'Lindenallee'),
    ];

    test('sendet die Adresse ohne c/o-Zeile', () async {
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.success(LatLng(50.9, 6.9)),
      );

      await serviceMit(mapService).resolveLocations(
        members: <Mitglied>[_memberWithAddress(careOf: 'c/o Erika Muster')],
      );

      expect(mapService.texts.single, 'Musterweg 4, 50667 Koeln, DE');
    });

    test('bricht bei Keine mobilen Daten nach der ersten Adresse ab', () async {
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.networkBlocked(
          deviceOffline: false,
          mobileDataBlocked: true,
        ),
      );

      final ergebnis = await serviceMit(mapService).resolveLocations(
        members: zweiMitglieder,
        stammAddress: 'Heim 1, Koeln',
      );

      expect(mapService.calls, 1);
      expect(ergebnis.memberPoints, isEmpty);
      expect(ergebnis.hinweis, StandortHinweis.keineMobilenDaten);
    });

    test('bricht bei Pause nach 429 ab und meldet sie', () async {
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.rateLimited(),
      );

      final ergebnis = await serviceMit(
        mapService,
      ).resolveLocations(members: zweiMitglieder);

      expect(mapService.calls, 1);
      expect(ergebnis.hinweis, StandortHinweis.pausiert);
    });

    test('sperrt technische Fehler je Adresse fuer 30 Minuten', () async {
      var jetzt = now;
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.technicalError(),
      );
      final service = serviceMit(mapService, nowProvider: () => jetzt);
      final mitglied = <Mitglied>[_memberWithAddress()];

      final erstes = await service.resolveLocations(members: mitglied);
      jetzt = now.add(const Duration(minutes: 29));
      final zweites = await service.resolveLocations(members: mitglied);

      expect(erstes.hinweis, StandortHinweis.unvollstaendig);
      expect(zweites.hinweis, StandortHinweis.unvollstaendig);
      expect(mapService.calls, 1);

      jetzt = now.add(const Duration(minutes: 31));
      mapService.result = const GeoapifyGeocodeResult.success(
        LatLng(50.9, 6.9),
      );
      final drittes = await service.resolveLocations(members: mitglied);

      expect(mapService.calls, 2);
      expect(drittes.hinweis, isNull);
      expect(drittes.memberPoints, hasLength(1));
    });

    test('fragt mit nurCache nichts an und liefert Cache-Treffer', () async {
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.success(LatLng(50.9, 6.9)),
      );
      final bekannt = zweiMitglieder.first.primaryAddress!;
      final fingerprint = MemberAddressUtils.fingerprint(bekannt);
      await repository.save(
        AddressMapLocation(
          cacheKey: fingerprint,
          latitude: 50.1,
          longitude: 6.1,
          resolvedAt: now,
          addressFingerprint: fingerprint,
        ),
      );

      final ergebnis = await serviceMit(
        mapService,
      ).resolveLocations(members: zweiMitglieder, nurCache: true);

      expect(mapService.calls, 0);
      expect(ergebnis.memberPoints.single.latitude, 50.1);
    });

    test('fragt ohne API-Key nichts an und meldet den Hinweis', () async {
      final mapService = _OhneKeyGeoapifyAddressMapService();

      final ergebnis = await serviceMit(
        mapService,
      ).resolveLocations(members: zweiMitglieder);

      expect(mapService.calls, 0);
      expect(ergebnis.hinweis, StandortHinweis.unvollstaendig);
    });

    test('fragt nach Abbruch nichts mehr an', () async {
      final mapService = _FakeGeoapifyAddressMapService(
        const GeoapifyGeocodeResult.success(LatLng(50.9, 6.9)),
      );

      await serviceMit(
        mapService,
      ).resolveLocations(members: zweiMitglieder, abgebrochen: () => true);

      expect(mapService.calls, 0);
    });
  });
}

Mitglied _memberWithAddress({
  String mitgliedsnummer = '1',
  String street = 'Musterweg',
  String? careOf,
}) => Mitglied.peopleListItem(
  mitgliedsnummer: mitgliedsnummer,
  vorname: 'Mara',
  nachname: 'Muster',
  adressen: <MitgliedKontaktAdresse>[
    MitgliedKontaktAdresse(
      additionalAddressId: 0,
      addressCareOf: careOf,
      street: street,
      housenumber: '4',
      zipCode: '50667',
      town: 'Koeln',
      country: 'DE',
    ),
  ],
);

class _FakeGeoapifyAddressMapService extends GeoapifyAddressMapService {
  _FakeGeoapifyAddressMapService(this.result) : super(apiKeyOverride: 'test');

  GeoapifyGeocodeResult result;
  int calls = 0;
  final List<String> texts = <String>[];

  @override
  Future<GeoapifyGeocodeResult> resolveAddress(String addressText) async {
    calls += 1;
    texts.add(addressText);
    return result;
  }
}

class _OhneKeyGeoapifyAddressMapService extends _FakeGeoapifyAddressMapService {
  _OhneKeyGeoapifyAddressMapService()
    : super(const GeoapifyGeocodeResult.technicalError());

  @override
  bool get hasApiKey => false;
}

class _InMemoryAddressMapLocationRepository
    implements AddressMapLocationRepository {
  final Map<String, AddressMapLocation> entries =
      <String, AddressMapLocation>{};

  @override
  Future<void> clearAll() async {
    entries.clear();
  }

  @override
  Future<int> countEntries() async => entries.length;

  @override
  Future<AddressMapLocation?> load(String cacheKey) async => entries[cacheKey];

  @override
  Future<void> remove(String cacheKey) async {
    entries.remove(cacheKey);
  }

  @override
  Future<void> save(AddressMapLocation location) async {
    entries[location.cacheKey] = location;
  }
}
