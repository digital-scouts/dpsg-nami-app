import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptik mit festen Bedeutungen (#278). Nur an festgelegten Momenten
/// einsetzen, nie beim normalen Tippen. Die Systemeinstellungen beider
/// Plattformen schalten sie ab.
///
/// [erfolg] und [fehler] wirken unter Android erst ab API 30; darunter
/// bleiben sie bewusst ohne Ersatz.
abstract final class AppHaptik {
  /// Meldet jede ausgelöste Bedeutung, z. B. für die Vorführung im
  /// Simulator, der selbst keine Haptik hat.
  @visibleForTesting
  static void Function(String bedeutung)? beobachter;

  /// Etwas rastet ein oder wird ausgewählt.
  static Future<void> auswahl() {
    beobachter?.call('auswahl');
    return HapticFeedback.selectionClick();
  }

  /// Ein Element wird angehoben, z. B. zum Verschieben.
  static Future<void> anheben() {
    beobachter?.call('anheben');
    return HapticFeedback.mediumImpact();
  }

  /// Ein angehobenes Element wird abgelegt.
  static Future<void> ablegen() {
    beobachter?.call('ablegen');
    return HapticFeedback.lightImpact();
  }

  /// Eine Aufgabe ist gelungen.
  static Future<void> erfolg() {
    beobachter?.call('erfolg');
    return HapticFeedback.successNotification();
  }

  /// Eine Aufgabe ist gescheitert.
  static Future<void> fehler() {
    beobachter?.call('fehler');
    return HapticFeedback.errorNotification();
  }
}
