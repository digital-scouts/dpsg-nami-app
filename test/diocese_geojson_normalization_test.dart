import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _forbiddenPrefixes = <String>[
  'Bistum ',
  'Erzbistum ',
  'Erzdiözese ',
  'Diözese ',
  'Offizialatsbezirk ',
];

void main() {
  test(
    'normalisiert Dioezesen im GeoJSON fachlich und aggregiert Muenster',
    () {
      final file = File('assets/maps/dioeceses.geojson');
      expect(file.existsSync(), isTrue);

      final decoded = jsonDecode(file.readAsStringSync(encoding: utf8));
      expect(decoded, isA<Map<String, dynamic>>());

      final features = (decoded as Map<String, dynamic>)['features'];
      expect(features, isA<List>());

      final featureMaps = (features as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final names = featureMaps
          .map(
            (feature) =>
                (feature['properties'] as Map<String, dynamic>)['name'],
          )
          .whereType<String>()
          .toList(growable: false);

      final ids = featureMaps
          .map(
            (feature) => (feature['properties'] as Map<String, dynamic>)['id'],
          )
          .whereType<String>()
          .toList(growable: false);

      expect(names, everyElement(startsWith('Diözesanverband ')));
      for (final prefix in _forbiddenPrefixes) {
        expect(names, isNot(contains(startsWith(prefix))));
      }
      expect(names, isNot(contains('Offizialatsbezirk Oldenburg')));
      expect(ids, isNot(contains('dioezesanverband-oldenburg')));

      final muensterFeatures = featureMaps
          .where((feature) {
            final properties = feature['properties'];
            if (properties is! Map<String, dynamic>) {
              return false;
            }
            return properties['id'] == 'dioezesanverband-muenster' &&
                properties['name'] == 'Diözesanverband Münster';
          })
          .toList(growable: false);

      expect(muensterFeatures, hasLength(1));
      expect(muensterFeatures.single['id'], 'dioezesanverband-muenster');

      final muensterProperties =
          muensterFeatures.single['properties'] as Map<String, dynamic>;
      final sourceNames = muensterProperties['sourceNames'];
      if (sourceNames != null) {
        expect(sourceNames, isA<List<dynamic>>());
        expect(
          (sourceNames as List<dynamic>).whereType<String>(),
          contains('Offizialatsbezirk Oldenburg'),
        );
      }
    },
  );
}
