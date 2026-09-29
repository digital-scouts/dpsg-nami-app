import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';

class AssetDioceseBoundaryRepository implements DioceseBoundaryRepository {
  const AssetDioceseBoundaryRepository({
    this.assetPath = 'assets/maps/dioeceses.geojson',
  });

  static const Map<String, String> _boundaryWebsitesById = {
    'dioezesanverband-aachen': 'http://www.dpsg-ac.de',
    'dioezesanverband-augsburg': 'http://www.dpsg-augsburg.de',
    'dioezesanverband-bamberg': 'http://www.dpsg-bamberg.de',
    'dioezesanverband-berlin': 'http://www.dpsg-dv-berlin.de',
    'dioezesanverband-eichstaett': 'http://www.dpsg-eichstaett.de',
    'dioezesanverband-essen': 'http://www.dpsg-essen.de',
    'dioezesanverband-erfurt': 'https://dpsg-thueringen.de',
    'dioezesanverband-freiburg': 'http://www.dpsg-freiburg.de',
    'dioezesanverband-fulda': 'http://www.dpsg-fulda.de',
    'dioezesanverband-hamburg': 'http://www.dpsg-hamburg.de',
    'dioezesanverband-hildesheim': 'http://www.dpsg-hildesheim.de',
    'dioezesanverband-koeln': 'http://www.dpsg-koeln.de',
    'dioezesanverband-limburg': 'http://www.dpsg-limburg.de',
    'dioezesanverband-magdeburg': 'http://www.dpsg-dv-magdeburg.de',
    'dioezesanverband-mainz': 'http://www.dpsg-mainz.de',
    'dioezesanverband-muenchen-und-freising': 'http://www.dpsg1300.de',
    'dioezesanverband-muenster': 'http://www.dpsgmuenster.de',
    'dioezesanverband-osnabrueck': 'https://dpsg-os.de',
    'dioezesanverband-paderborn': 'http://www.dpsg-paderborn.de',
    'dioezesanverband-passau': 'http://www.dpsg-passau.de',
    'dioezesanverband-regensburg': 'http://www.dpsg-regensburg.de',
    'dioezesanverband-rottenburg-stuttgart': 'http://www.dpsg-rottenburg.de',
    'dioezesanverband-speyer': 'http://www.dpsg-speyer.org',
    'dioezesanverband-trier': 'http://www.dpsg-trier.de',
    'dioezesanverband-wuerzburg': 'http://www.dpsg-wuerzburg.de',
  };

  final String assetPath;

  @override
  Future<List<DioceseBoundary>> loadBoundaries() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GeoJSON muss ein JSON-Objekt sein.');
    }

    final features = decoded['features'];
    if (features is! List) {
      throw const FormatException('GeoJSON FeatureCollection ohne features.');
    }

    final mergedById = <String, DioceseBoundary>{};
    for (final feature in features.whereType<Map<String, dynamic>>()) {
      final boundary = _parseFeature(feature);
      if (boundary == null) {
        continue;
      }

      final existing = mergedById[boundary.id];
      if (existing == null) {
        mergedById[boundary.id] = boundary;
        continue;
      }

      mergedById[boundary.id] = DioceseBoundary(
        id: existing.id,
        name: existing.name,
        polygons: [...existing.polygons, ...boundary.polygons],
        website: existing.website ?? boundary.website,
      );
    }

    return mergedById.values.toList(growable: false);
  }

  DioceseBoundary? _parseFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) {
      return null;
    }

    final polygons = _parseGeometry(geometry);
    if (polygons.isEmpty) {
      return null;
    }

    final properties = feature['properties'];
    final props = properties is Map<String, dynamic>
        ? properties
        : const <String, dynamic>{};
    final id =
        _readString(props['id']) ??
        _readString(props['gis_id_bistum']) ??
        _readString(props['gis_id']) ??
        _readString(feature['id']) ??
        props.hashCode.toString();
    final name =
        _readString(props['name']) ??
        _readString(props['bistum_name']) ??
        _readString(props['label']) ??
        id;
    final website = _readString(props['website']) ?? _boundaryWebsitesById[id];

    return DioceseBoundary(
      id: id,
      name: name,
      polygons: polygons,
      website: website,
    );
  }

  List<DioceseBoundaryPolygon> _parseGeometry(Map<String, dynamic> geometry) {
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    if (type == 'Polygon' && coordinates is List) {
      final polygon = _parsePolygonCoordinates(coordinates);
      return polygon == null ? const [] : [polygon];
    }
    if (type == 'MultiPolygon' && coordinates is List) {
      return coordinates
          .whereType<List>()
          .map(_parsePolygonCoordinates)
          .whereType<DioceseBoundaryPolygon>()
          .toList(growable: false);
    }
    return const [];
  }

  DioceseBoundaryPolygon? _parsePolygonCoordinates(List rings) {
    if (rings.isEmpty) {
      return null;
    }

    final outer = _parseRing(rings.first);
    if (outer.length < 3) {
      return null;
    }

    final holes = rings
        .skip(1)
        .map(_parseRing)
        .where((ring) => ring.length >= 3)
        .toList(growable: false);
    return DioceseBoundaryPolygon(points: outer, holes: holes);
  }

  List<LatLng> _parseRing(Object? ring) {
    if (ring is! List) {
      return const [];
    }

    final points = ring
        .whereType<List>()
        .map(_parseCoordinate)
        .whereType<LatLng>()
        .toList(growable: false);
    if (points.length >= 2 && points.first == points.last) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  }

  LatLng? _parseCoordinate(List coordinate) {
    if (coordinate.length < 2) {
      return null;
    }
    final lon = _toDouble(coordinate[0]);
    final lat = _toDouble(coordinate[1]);
    if (lon == null || lat == null) {
      return null;
    }
    return LatLng(lat, lon);
  }

  String? _readString(Object? value) {
    final stringValue = value?.toString().trim();
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }
    return stringValue;
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
