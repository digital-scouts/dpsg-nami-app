import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/statistiks/statistik_verlauf.dart';

/// Monatliche Summen je Stamm, nur auf dem Gerät. Abmelden, Datenablauf und
/// Kontowechsel löschen sie über `clearAll`, der App-Reset mit allen anderen
/// SharedPreferences.
class SharedPrefsStatistikVerlaufRepository
    implements StatistikVerlaufRepository {
  static const String _keyPrefix = 'statistikVerlauf';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<List<StatistikVerlaufEintrag>> loadForLayer(int layerId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_keyForLayer(layerId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List.unmodifiable(
        decoded
            .map(StatistikVerlaufEintrag.fromJson)
            .whereType<StatistikVerlaufEintrag>(),
      );
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    List<StatistikVerlaufEintrag> eintraege,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(
      _keyForLayer(layerId),
      jsonEncode(eintraege.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _prefs();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('$_keyPrefix:'))
        .toList(growable: false);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  String _keyForLayer(int layerId) => '$_keyPrefix:$layerId';
}

class InMemoryStatistikVerlaufRepository implements StatistikVerlaufRepository {
  final Map<int, List<StatistikVerlaufEintrag>> _werte = {};

  @override
  Future<List<StatistikVerlaufEintrag>> loadForLayer(int layerId) async =>
      _werte[layerId] ?? const [];

  @override
  Future<void> saveForLayer(
    int layerId,
    List<StatistikVerlaufEintrag> eintraege,
  ) async {
    _werte[layerId] = List.unmodifiable(eintraege);
  }

  @override
  Future<void> clearAll() async => _werte.clear();
}
