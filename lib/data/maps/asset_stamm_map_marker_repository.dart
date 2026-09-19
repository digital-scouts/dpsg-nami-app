import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/maps/stamm_map_marker.dart';

class AssetStammMapMarkerRepository {
  const AssetStammMapMarkerRepository({
    this.assetPath = 'assets/maps/stamm_markers.json',
  });

  final String assetPath;

  Future<StammMapMarkerSnapshot> loadFallback() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Stammmarker-Asset muss ein JSON-Objekt sein.',
      );
    }

    final snapshot = StammMapMarkerSnapshot.fromJson(decoded);
    return snapshot.copyWith(source: StammMapMarkerSource.asset);
  }
}
