import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/maps/stamm_map_marker.dart';

typedef StammStorelocatorLog = Future<void> Function(String message);

class StammStorelocatorService {
  StammStorelocatorService({
    http.Client? client,
    StammStorelocatorLog? log,
    Duration? requestTimeout,
  }) : _client = client ?? http.Client(),
       _log = log,
       _requestTimeout = requestTimeout ?? const Duration(seconds: 15);

  static const double germanyCenterLat = 51.220915;
  static const double germanyCenterLng = 9.357579;
  static const int radiusKm = 1000;

  final http.Client _client;
  final StammStorelocatorLog? _log;
  final Duration _requestTimeout;

  Future<List<StammMapMarker>> fetchMarkers() async {
    final uri = Uri.https('tools.dpsg.de', '/stammessuche/storelocator.php', {
      'lat': germanyCenterLat.toString(),
      'lng': germanyCenterLng.toString(),
      'radius': radiusKm.toString(),
    });

    await _log?.call('Stammesuche-Request gestartet: $uri');
    final response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Stammesuche lieferte Status ${response.statusCode}.');
    }

    final markers = parseMarkers(response.body);
    await _log?.call(
      'Stammesuche erfolgreich geladen: ${markers.length} Marker',
    );
    return markers;
  }

  static List<StammMapMarker> parseMarkers(String xmlBody) {
    final document = XmlDocument.parse(xmlBody);
    final elements = document.findAllElements('marker');

    return elements
        .map(_parseMarker)
        .whereType<StammMapMarker>()
        .where((marker) => marker.hasDisplayableAddress)
        .toList(growable: false);
  }

  static StammMapMarker? _parseMarker(XmlElement element) {
    final latitude = double.tryParse(element.getAttribute('lat') ?? '');
    final longitude = double.tryParse(element.getAttribute('lng') ?? '');
    final name = (element.getAttribute('stammname') ?? '').trim();
    if (latitude == null || longitude == null || name.isEmpty) {
      return null;
    }

    return StammMapMarker(
      id: (element.getAttribute('id') ?? '').trim(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      street: (element.getAttribute('adresse') ?? '').trim(),
      city: (element.getAttribute('ort') ?? '').trim(),
      postalCode: (element.getAttribute('plz') ?? '').trim(),
      website: (element.getAttribute('www') ?? '').trim(),
    );
  }
}
