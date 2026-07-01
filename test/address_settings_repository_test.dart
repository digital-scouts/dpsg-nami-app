import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';

void main() {
  test('InMemoryAddressSettingsRepository saves and loads address', () async {
    final repo = InMemoryAddressSettingsRepository();
    expect(await repo.loadAddress(), isNull);

    await repo.saveAddress('Musterstraße 1, 12345 Musterstadt');
    expect(await repo.loadAddress(), 'Musterstraße 1, 12345 Musterstadt');
  });

  test('watchAddress emits on save', () async {
    final repo = InMemoryAddressSettingsRepository();
    final emissions = <String?>[];
    final sub = repo.watchAddress().listen(emissions.add);

    await repo.saveAddress('A');
    await repo.saveAddress('B');

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(emissions, ['A', 'B']);
  });
}
