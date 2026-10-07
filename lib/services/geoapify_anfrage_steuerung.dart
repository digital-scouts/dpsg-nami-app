import 'package:shared_preferences/shared_preferences.dart';

/// Prozessweite Steuerung der Geoapify-Geokodierung.
///
/// Teilt laufende Anfragen je Adresstext, damit parallele Aufrufer (Statistik,
/// Detailkarte, erneute Läufe nach einem Neuaufbau) keine Doppelanfragen
/// erzeugen. Nach HTTP 429 pausiert sie alle Geokodierungen; die Pause
/// überdauert einen Neustart, damit erschöpfte Kontingente nicht weiter
/// belastet werden.
class GeoapifyAnfrageSteuerung {
  GeoapifyAnfrageSteuerung({DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  /// Gemeinsame Instanz aller Geoapify-Dienste der App.
  static final GeoapifyAnfrageSteuerung geteilt = GeoapifyAnfrageSteuerung();

  static const String pauseKey = 'geoapify_pause_bis';

  /// Pause nach 429 ohne verwertbares `Retry-After`.
  static const Duration standardPause = Duration(hours: 1);

  final DateTime Function() _now;
  final Map<String, Future<Object?>> _laufend = <String, Future<Object?>>{};

  /// Führt [anfrage] aus oder hängt sich an eine laufende Anfrage mit
  /// demselben [schluessel].
  Future<T> teilen<T>(String schluessel, Future<T> Function() anfrage) async {
    final laufend = _laufend[schluessel];
    if (laufend != null) {
      return await laufend as T;
    }
    final future = anfrage();
    _laufend[schluessel] = future;
    try {
      return await future;
    } finally {
      _laufend.remove(schluessel);
    }
  }

  /// Ende der aktiven Pause oder `null`, wenn keine Pause läuft.
  Future<DateTime?> pauseBis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(pauseKey);
      final bis = raw == null ? null : DateTime.tryParse(raw);
      if (bis == null) {
        return null;
      }
      if (!bis.isAfter(_now())) {
        await prefs.remove(pauseKey);
        return null;
      }
      return bis;
    } catch (_) {
      return null;
    }
  }

  /// Pausiert die Geokodierung nach einem 429 für [retryAfter] bzw.
  /// [standardPause].
  Future<DateTime> pausieren({Duration? retryAfter}) async {
    final dauer = retryAfter == null || retryAfter <= Duration.zero
        ? standardPause
        : retryAfter;
    final bis = _now().add(dauer);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pauseKey, bis.toIso8601String());
    } catch (_) {
      // Ohne Speicher gilt die Pause nur fuer diesen Lauf.
    }
    return bis;
  }

  /// Wertet einen `Retry-After`-Header in Sekunden aus; andere Formate
  /// fallen auf [standardPause] zurück.
  static Duration? retryAfterAus(String? header) {
    final sekunden = int.tryParse(header?.trim() ?? '');
    return sekunden == null ? null : Duration(seconds: sekunden);
  }
}
