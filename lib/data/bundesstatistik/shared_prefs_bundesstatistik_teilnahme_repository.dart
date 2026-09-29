import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/bundesstatistik/bundesstatistik_teilnahme.dart';

class SharedPrefsBundesstatistikTeilnahmeRepository
    implements BundesstatistikTeilnahmeRepository {
  SharedPrefsBundesstatistikTeilnahmeRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const String _keyEinwilligungFuer = 'bundesstatistikEinwilligungFuer';
  static const String _keyEinwilligungAm = 'bundesstatistikEinwilligungAm';
  static const String _keyZuletztGesendetAm =
      'bundesstatistikZuletztGesendetAm';
  static const String _keyZuletztGesendeterStammId =
      'bundesstatistikZuletztGesendeterStammId';
  static const String _keyZuletztGesendeterSnapshot =
      'bundesstatistikZuletztGesendeterSnapshot';

  final Future<SharedPreferences> Function() _preferencesProvider;

  @override
  Future<BundesstatistikTeilnahme> load() async {
    final prefs = await _preferencesProvider();
    return BundesstatistikTeilnahme(
      einwilligungFuer: prefs.getString(_keyEinwilligungFuer),
      einwilligungAm: _toDateTime(prefs.getString(_keyEinwilligungAm)),
      zuletztGesendetAm: _toDateTime(prefs.getString(_keyZuletztGesendetAm)),
      zuletztGesendeterStammId: prefs.getString(_keyZuletztGesendeterStammId),
      zuletztGesendeterSnapshotJson: prefs.getString(
        _keyZuletztGesendeterSnapshot,
      ),
    );
  }

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async {
    final prefs = await _preferencesProvider();
    await _setOrRemove(prefs, _keyEinwilligungFuer, teilnahme.einwilligungFuer);
    await _setOrRemove(
      prefs,
      _keyEinwilligungAm,
      teilnahme.einwilligungAm?.toUtc().toIso8601String(),
    );
    await _setOrRemove(
      prefs,
      _keyZuletztGesendetAm,
      teilnahme.zuletztGesendetAm?.toUtc().toIso8601String(),
    );
    await _setOrRemove(
      prefs,
      _keyZuletztGesendeterStammId,
      teilnahme.zuletztGesendeterStammId,
    );
    await _setOrRemove(
      prefs,
      _keyZuletztGesendeterSnapshot,
      teilnahme.zuletztGesendeterSnapshotJson,
    );
  }

  Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  DateTime? _toDateTime(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
