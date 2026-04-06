import 'address_map_location.dart';

abstract class AddressMapLocationRepository {
  Future<AddressMapLocation?> load(String cacheKey);
  Future<void> save(AddressMapLocation location);
  Future<void> remove(String cacheKey);
}
