import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/member_filters/member_filter_repository.dart';

class SharedPrefsMemberFilterRepository implements MemberFilterRepository {
  static const String _keyPrefix = 'memberFilterLayerSettings';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<MemberFilterLayerSettings> loadForLayer(int layerId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_keyForLayer(layerId));
    if (raw == null || raw.isEmpty) {
      return const MemberFilterLayerSettings();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const MemberFilterLayerSettings();
    }

    return MemberFilterLayerSettings.fromJson(decoded);
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    MemberFilterLayerSettings settings,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(_keyForLayer(layerId), jsonEncode(settings.toJson()));
  }

  String _keyForLayer(int layerId) => '$_keyPrefix:$layerId';
}
