import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/qualifikation/qualifikations_einstellungen.dart';
import '../../domain/qualifikation/qualifikations_einstellungen_repository.dart';

/// Einstellungen als JSON unter einem Schluessel. Sie ueberstehen den
/// Logout und werden erst beim vollstaendigen Zuruecksetzen geloescht.
class SharedPrefsQualifikationsEinstellungenRepository
    implements QualifikationsEinstellungenRepository {
  static const _key = 'qualifikationsEinstellungenJson';

  @override
  Future<QualifikationsEinstellungen> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const QualifikationsEinstellungen();
    }
    try {
      return QualifikationsEinstellungen.fromJson(jsonDecode(raw));
    } on FormatException {
      return const QualifikationsEinstellungen();
    }
  }

  @override
  Future<void> save(QualifikationsEinstellungen einstellungen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(einstellungen.toJson()));
  }
}
