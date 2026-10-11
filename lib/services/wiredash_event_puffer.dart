import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

typedef WiredashSendenErlaubt = Future<bool> Function();

/// Wirft der Sender, solange Wiredash noch nicht eingehaengt ist. Das
/// Ereignis bleibt dann vorgemerkt.
class WiredashNichtBereit implements Exception {
  const WiredashNichtBereit();
}

/// Haelt Nutzungsereignisse zurueck, solange Senden nicht erlaubt ist, etwa
/// bei „Mobile Daten einschränken“ ohne WLAN. Wiredash selbst sendet jedes
/// Ereignis nach wenigen Sekunden und laesst sich nicht pausieren; deshalb
/// erreicht ein Ereignis Wiredash erst, wenn es gesendet werden darf.
class WiredashEventPuffer {
  WiredashEventPuffer({
    required WiredashEventHook senden,
    required WiredashSendenErlaubt sendenErlaubt,
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? nowProvider,
    this.maxEreignisse = 200,
    this.maxAlter = const Duration(days: 3),
  }) : _senden = senden,
       _sendenErlaubt = sendenErlaubt,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _now = nowProvider ?? DateTime.now;

  static const String speicherSchluessel = 'wiredash_event_puffer';

  /// Wiredash nimmt hoechstens zehn Parameter je Ereignis an.
  static const int _maxParameter = 10;

  final WiredashEventHook _senden;
  final WiredashSendenErlaubt _sendenErlaubt;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _now;
  final int maxEreignisse;
  final Duration maxAlter;

  // Erfassen und Nachsenden laufen nacheinander, damit die Reihenfolge
  // erhalten bleibt und kein Ereignis doppelt rausgeht.
  Future<void> _kette = Future<void>.value();

  /// Sendet [name] direkt oder merkt es vor.
  Future<void> erfasse(String name, Map<String, Object?> properties) {
    return _nacheinander(() async {
      if (await _sendenErlaubt()) {
        try {
          await _sendeVorgemerkte();
          await _senden(name, properties);
          return;
        } on WiredashNichtBereit {
          // Faellt auf Vormerken zurueck und geht beim naechsten Anlass raus.
        }
      }
      await _vormerken(name, properties);
    });
  }

  /// Sendet vorgemerkte Ereignisse, sobald Senden erlaubt ist.
  Future<void> sendeAusstehende() {
    return _nacheinander(() async {
      final prefs = await _preferencesProvider();
      if (!prefs.containsKey(speicherSchluessel)) {
        return;
      }
      if (await _sendenErlaubt()) {
        try {
          await _sendeVorgemerkte();
        } on WiredashNichtBereit {
          // Bleibt vorgemerkt.
        }
      }
    });
  }

  Future<void> _nacheinander(Future<void> Function() aktion) {
    final next = _kette.then((_) => aktion());
    _kette = next.catchError((Object _) {});
    return next;
  }

  Future<void> _vormerken(String name, Map<String, Object?> properties) async {
    final prefs = await _preferencesProvider();
    final eintraege = _lese(prefs)
      ..add(<String, Object?>{
        'name': name,
        'zeit': _now().toUtc().toIso8601String(),
        'daten': properties,
      });
    final ueberzaehlig = eintraege.length - maxEreignisse;
    if (ueberzaehlig > 0) {
      eintraege.removeRange(0, ueberzaehlig);
    }
    await prefs.setString(speicherSchluessel, jsonEncode(eintraege));
  }

  Future<void> _sendeVorgemerkte() async {
    final prefs = await _preferencesProvider();
    final eintraege = _lese(prefs);
    if (eintraege.isEmpty) {
      await prefs.remove(speicherSchluessel);
      return;
    }
    final grenze = _now().toUtc().subtract(maxAlter);
    while (eintraege.isNotEmpty) {
      final eintrag = eintraege.first;
      final zeit = DateTime.tryParse(eintrag['zeit'] as String? ?? '');
      if (zeit != null && zeit.isAfter(grenze)) {
        final daten = Map<String, Object?>.from(
          eintrag['daten'] as Map? ?? const <String, Object?>{},
        );
        // Wiredash stempelt beim Uebergeben; der echte Zeitpunkt reist mit.
        if (daten.length < _maxParameter) {
          daten['occurred_at'] = zeit.toIso8601String();
        }
        await _senden(eintrag['name'] as String, daten);
      }
      eintraege.removeAt(0);
      if (eintraege.isEmpty) {
        await prefs.remove(speicherSchluessel);
      } else {
        await prefs.setString(speicherSchluessel, jsonEncode(eintraege));
      }
    }
  }

  List<Map<String, Object?>> _lese(SharedPreferences prefs) {
    final raw = prefs.getString(speicherSchluessel);
    if (raw == null || raw.isEmpty) {
      return <Map<String, Object?>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, Object?>>[];
      }
      return [
        for (final eintrag in decoded)
          if (eintrag is Map && eintrag['name'] is String)
            Map<String, Object?>.from(eintrag),
      ];
    } on FormatException {
      return <Map<String, Object?>>[];
    }
  }
}
