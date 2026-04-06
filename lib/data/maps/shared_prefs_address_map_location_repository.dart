import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/maps/address_map_location.dart';
import '../../domain/maps/address_map_location_repository.dart';

class SharedPrefsAddressMapLocationRepository
    implements AddressMapLocationRepository {
  static const String _keyPrefix = 'addressMapLocation.';

  @override
  Future<AddressMapLocation?> load(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$cacheKey');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AddressMapLocation.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AddressMapLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${location.cacheKey}',
      jsonEncode(location.toJson()),
    );
  }

  @override
  Future<void> remove(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$cacheKey');
  }
}
