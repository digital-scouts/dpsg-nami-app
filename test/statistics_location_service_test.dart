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
}

Mitglied _memberWithAddress() => Mitglied.peopleListItem(
  mitgliedsnummer: '1',
  vorname: 'Mara',
  nachname: 'Muster',
  adressen: const <MitgliedKontaktAdresse>[
    MitgliedKontaktAdresse(
      street: 'Musterweg',
      housenumber: '4',
      zipCode: '50667',
      town: 'Koeln',
      country: 'DE',
    ),
  ],
);

class _FakeGeoapifyAddressMapService extends GeoapifyAddressMapService {
  _FakeGeoapifyAddressMapService(this.result) : super(apiKeyOverride: 'test');

  final GeoapifyGeocodeResult result;
  int calls = 0;

  @override
  Future<GeoapifyGeocodeResult> resolveAddress(String addressText) async {
    calls += 1;
    return result;
  }
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
