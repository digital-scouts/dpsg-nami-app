import 'package:latlong2/latlong.dart';

class DioceseBoundaryPolygon {
  const DioceseBoundaryPolygon({required this.points, this.holes = const []});

  final List<LatLng> points;
  final List<List<LatLng>> holes;
}

class DioceseBoundary {
  const DioceseBoundary({
    required this.id,
    required this.name,
    required this.polygons,
    this.website,
  });

  final String id;
  final String name;
  final List<DioceseBoundaryPolygon> polygons;
  final String? website;
}
