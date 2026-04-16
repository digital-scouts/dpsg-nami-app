import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/stufen_settings.dart';
import '../../domain/settings/stufen_settings_repository.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../../domain/taetigkeit/stufe.dart';

class SharedPrefsStufenSettingsRepository implements StufenSettingsRepository {
  static const _keyStufenwechsel = 'stufenwechselDate';
  static const _keyGrenzen = 'altersgrenzenJson';

  @override
  Future<StufenSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dateMillis = prefs.getInt(_keyStufenwechsel);
    final grenzenJson = prefs.getString(_keyGrenzen);
    final date = dateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
        : null;
    final grenzen = grenzenJson != null
        ? _decodeGrenzen(grenzenJson)
        : StufenDefaults.build();
    return StufenSettings(grenzen: grenzen, stufenwechselDatum: date);
  }

  @override
  Future<void> saveAltersgrenzen(StufenSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGrenzen, _encodeGrenzen(settings.grenzen));
  }

  @override
  Future<void> saveStufenwechselDatum(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_keyStufenwechsel);
    } else {
      await prefs.setInt(_keyStufenwechsel, date.millisecondsSinceEpoch);
    }
  }
}

Altersgrenzen _decodeGrenzen(String json) {
  final map = Map<String, dynamic>.from(
    (jsonDecode(json) as Map<String, dynamic>),
  );
  final grenzen = <Stufe, AltersIntervall>{};
  map.forEach((key, value) {
    final v = value as Map<String, dynamic>;
    final stufe = Stufe.values.firstWhere((s) => s.name == key);
    grenzen[stufe] = AltersIntervall(
      minJahre: v['min'] as int,
      maxJahre: v['max'] as int,
    );
  });
  return Altersgrenzen(grenzen);
}

String _encodeGrenzen(Altersgrenzen g) {
  final map = <String, Map<String, int>>{};
  g.grenzen.forEach((stufe, intervall) {
    map[stufe.name] = {'min': intervall.minJahre, 'max': intervall.maxJahre};
  });
  return jsonEncode(map);
}
