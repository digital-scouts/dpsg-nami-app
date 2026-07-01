import 'dart:async';

import 'package:nami/domain/settings/address_settings_repository.dart';

class InMemoryAddressSettingsRepository implements AddressSettingsRepository {
  String? _address;
  final _controller = StreamController<String?>.broadcast();

  @override
  Future<String?> loadAddress() async => _address;

  @override
  Future<void> saveAddress(String address) async {
    _address = address;
    _controller.add(_address);
  }

  @override
  Stream<String?> watchAddress() => _controller.stream;
}
