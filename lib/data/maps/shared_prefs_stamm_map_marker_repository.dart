import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/maps/stamm_map_marker.dart';

class SharedPrefsStammMapMarkerRepository {
  static const String _storageKey = 'stammMapMarkers.snapshot';

  Future<StammMapMarkerSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return StammMapMarkerSnapshot.fromJson(
        decoded,
      ).copyWith(source: StammMapMarkerSource.cache);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(StammMapMarkerSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
