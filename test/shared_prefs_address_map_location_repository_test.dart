import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/maps/shared_prefs_address_map_location_repository.dart';
import 'package:nami/domain/maps/address_map_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('speichert und laedt AddressMapLocation in SharedPreferences', () async {
    final repository = SharedPrefsAddressMapLocationRepository();
    final location = AddressMapLocation(
      cacheKey: '23:0',
      latitude: 53.5511,
      longitude: 9.9937,
      resolvedAt: DateTime(2026, 4, 6, 10, 15),
      addressFingerprint: 'abc123',
    );

    await repository.save(location);

    expect(await repository.load('23:0'), location);
  });

  test('entfernt gespeicherte AddressMapLocation wieder', () async {
    final repository = SharedPrefsAddressMapLocationRepository();
    await repository.save(
      AddressMapLocation(
        cacheKey: '23:0',
        latitude: 53.5511,
        longitude: 9.9937,
        resolvedAt: DateTime(2026, 4, 6, 10, 15),
      ),
    );

    await repository.remove('23:0');

    expect(await repository.load('23:0'), isNull);
  });

  test(
    'speichert und laedt Negativ-Cache fuer nicht gefundene Adresse',
    () async {
      final repository = SharedPrefsAddressMapLocationRepository();
      final location = AddressMapLocation(
        cacheKey: 'stamm:0',
        resolvedAt: DateTime(2026, 4, 6, 11, 30),
        addressFingerprint: 'missing123',
        addressNotFound: true,
      );

      await repository.save(location);

      expect(await repository.load('stamm:0'), location);
    },
  );
}
