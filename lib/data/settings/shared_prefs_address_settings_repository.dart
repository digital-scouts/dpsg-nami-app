import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/address_settings_repository.dart';

class SharedPrefsAddressSettingsRepository
    implements AddressSettingsRepository {
  static const String _keyAddress = 'stammAddress';

  @override
  Future<String?> loadAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAddress);
  }

  @override
  Future<void> saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddress, address);
    _controller.add(address);
  }

  final StreamController<String?> _controller = StreamController.broadcast();

  @override
  Stream<String?> watchAddress() => _controller.stream;
}
