import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/address_autocomplete_provider.dart' as provider;

void main() {
  group('geoapifyAutocompleteProvider', () {
    test('returns empty for short queries', () async {
      final res = await provider.geoapifyAutocompleteProvider('ab');
      expect(res, isEmpty);
    });
  });
}
