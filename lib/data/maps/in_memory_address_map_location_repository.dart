import '../../domain/maps/address_map_location.dart';
import '../../domain/maps/address_map_location_repository.dart';

class InMemoryAddressMapLocationRepository
    implements AddressMapLocationRepository {
  final Map<String, AddressMapLocation> _entries =
      <String, AddressMapLocation>{};

  @override
  Future<AddressMapLocation?> load(String cacheKey) async => _entries[cacheKey];

  @override
  Future<void> save(AddressMapLocation location) async {
    _entries[location.cacheKey] = location;
  }

  @override
  Future<void> remove(String cacheKey) async {
    _entries.remove(cacheKey);
  }
}
