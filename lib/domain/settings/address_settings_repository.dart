abstract class AddressSettingsRepository {
  Future<String?> loadAddress();
  Future<void> saveAddress(String address);
  Stream<String?> watchAddress();
}
