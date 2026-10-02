import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/bundesstatistik/bundesstatistik_teilnahme.dart';

class SharedPrefsBundesstatistikTeilnahmeRepository
    implements BundesstatistikTeilnahmeRepository {
  SharedPrefsBundesstatistikTeilnahmeRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const String _keyEinwilligungFuer = 'bundesstatistikEinwilligungFuer';
  static const String _keyEinwilligungen = 'bundesstatistikEinwilligungen';
  static const String _keySendestaende = 'bundesstatistikSendestaende';

  // Frueherer Stand mit genau einem Stamm; wird beim Laden uebernommen und
  // beim Speichern entfernt.
  static const String _keyAltEinwilligungAm = 'bundesstatistikEinwilligungAm';
  static const String _keyAltZuletztGesendetAm =
      'bundesstatistikZuletztGesendetAm';
  static const String _keyAltZuletztGesendeterStammId =
      'bundesstatistikZuletztGesendeterStammId';
  static const String _keyAltZuletztGesendeterSnapshot =
      'bundesstatistikZuletztGesendeterSnapshot';

  final Future<SharedPreferences> Function() _preferencesProvider;

  @override
  Future<BundesstatistikTeilnahme> load() async {
    final prefs = await _preferencesProvider();
    final einwilligungFuer = prefs.getString(_keyEinwilligungFuer);
    final einwilligungen = _ladeMap(
      prefs.getString(_keyEinwilligungen),
      (value) => DateTime.tryParse(value?.toString() ?? ''),
    );
    final sendestaende = _ladeMap(
      prefs.getString(_keySendestaende),
      (value) => value is Map<String, dynamic>
          ? StammSendestand.fromJson(value)
          : null,
    );

    final altStammId = prefs.getString(_keyAltZuletztGesendeterStammId);
    if (altStammId != null && sendestaende.isEmpty) {
      sendestaende[altStammId] = StammSendestand(
        am: _toDateTime(prefs.getString(_keyAltZuletztGesendetAm)),
        snapshotJson: prefs.getString(_keyAltZuletztGesendeterSnapshot),
      );
      final altEinwilligungAm = _toDateTime(
        prefs.getString(_keyAltEinwilligungAm),
      );
      if (einwilligungFuer != null && altEinwilligungAm != null) {
        einwilligungen.putIfAbsent(altStammId, () => altEinwilligungAm);
      }
    }

    return BundesstatistikTeilnahme(
      einwilligungFuer: einwilligungFuer,
      einwilligungen: einwilligungen,
      sendestaende: sendestaende,
    );
  }

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async {
    final prefs = await _preferencesProvider();
    final einwilligungFuer = teilnahme.einwilligungFuer;
    if (einwilligungFuer == null) {
      await prefs.remove(_keyEinwilligungFuer);
    } else {
      await prefs.setString(_keyEinwilligungFuer, einwilligungFuer);
    }
    await prefs.setString(
      _keyEinwilligungen,
      jsonEncode({
        for (final entry in teilnahme.einwilligungen.entries)
          entry.key: entry.value.toUtc().toIso8601String(),
      }),
    );
    await prefs.setString(
      _keySendestaende,
      jsonEncode({
        for (final entry in teilnahme.sendestaende.entries)
          entry.key: entry.value.toJson(),
      }),
    );
    for (final key in const [
      _keyAltEinwilligungAm,
      _keyAltZuletztGesendetAm,
      _keyAltZuletztGesendeterStammId,
      _keyAltZuletztGesendeterSnapshot,
    ]) {
      await prefs.remove(key);
    }
  }

  Map<String, T> _ladeMap<T>(String? json, T? Function(Object? value) wert) {
    if (json == null) {
      return <String, T>{};
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        return <String, T>{};
      }
      return <String, T>{
        for (final entry in decoded.entries) entry.key: ?wert(entry.value),
      };
    } catch (_) {
      return <String, T>{};
    }
  }

  DateTime? _toDateTime(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
