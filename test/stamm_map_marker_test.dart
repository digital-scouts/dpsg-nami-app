import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';

void main() {
  test('ordnet Stammmarker-Farblogik ueber den Namen zu', () {
    expect(
      const StammMapMarker(
        id: '1',
        name: 'Bezirk Rhein-Sieg',
        latitude: 0,
        longitude: 0,
      ).category,
      StammMapMarkerCategory.district,
    );

    expect(
      const StammMapMarker(
        id: '2',
        name: 'Diözesanleitung Fulda',
        latitude: 0,
        longitude: 0,
      ).category,
      StammMapMarkerCategory.diocese,
    );

    expect(
      const StammMapMarker(
        id: '3',
        name: 'DPSG Bundesverband',
        latitude: 0,
        longitude: 0,
      ).category,
      StammMapMarkerCategory.federal,
    );

    expect(
      const StammMapMarker(
        id: '4',
        name: 'Stamm Polaris',
        latitude: 0,
        longitude: 0,
      ).category,
      StammMapMarkerCategory.standard,
    );
  });
}