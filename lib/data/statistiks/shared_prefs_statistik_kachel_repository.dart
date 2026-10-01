import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/statistiks/statistik_kachel_einstellungen.dart';

class SharedPrefsStatistikKachelRepository
    implements StatistikKachelRepository {
  static const String _keyPrefix = 'statistikKacheln';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<StatistikKachelEinstellungen> loadForLayer(int layerId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_keyForLayer(layerId));
    if (raw == null || raw.isEmpty) {
      return const StatistikKachelEinstellungen();
    }
    try {
      return StatistikKachelEinstellungen.fromJson(jsonDecode(raw));
    } on FormatException {
      return const StatistikKachelEinstellungen();
    }
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    StatistikKachelEinstellungen einstellungen,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(
      _keyForLayer(layerId),
      jsonEncode(einstellungen.toJson()),
    );
  }

  String _keyForLayer(int layerId) => '$_keyPrefix:$layerId';
}

class InMemoryStatistikKachelRepository implements StatistikKachelRepository {
  final Map<int, StatistikKachelEinstellungen> _werte = {};

  @override
  Future<StatistikKachelEinstellungen> loadForLayer(int layerId) async =>
      _werte[layerId] ?? const StatistikKachelEinstellungen();

  @override
  Future<void> saveForLayer(
    int layerId,
    StatistikKachelEinstellungen einstellungen,
  ) async {
    _werte[layerId] = einstellungen;
  }
}
