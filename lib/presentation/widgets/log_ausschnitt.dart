import 'package:flutter/foundation.dart';

/// Zeitfenster einer Log-Ansicht; ohne Grenzen sind alle Eintraege sichtbar.
@immutable
class LogZeitfenster {
  const LogZeitfenster({this.von, this.bis});

  static const LogZeitfenster alles = LogZeitfenster();

  final DateTime? von;
  final DateTime? bis;

  bool get istAlles => von == null && bis == null;

  bool enthaelt(DateTime zeitpunkt) =>
      (von == null || !zeitpunkt.isBefore(von!)) &&
      (bis == null || !zeitpunkt.isAfter(bis!));

  @override
  bool operator ==(Object other) =>
      other is LogZeitfenster && other.von == von && other.bis == bis;

  @override
  int get hashCode => Object.hash(von, bis);
}

/// Was eine Log-Ansicht gerade zeigt: die Rohzeilen in chronologischer
/// Reihenfolge, die Zahl der Eintraege und die aktiven Filter als Text.
/// Grundlage fuer Teilen und Report Issue.
@immutable
class LogAusschnitt {
  const LogAusschnitt({
    required this.zeilen,
    required this.eintraege,
    this.filter = const <String>[],
  });

  static const LogAusschnitt leer = LogAusschnitt(
    zeilen: <String>[],
    eintraege: 0,
  );

  final List<String> zeilen;
  final int eintraege;
  final List<String> filter;

  @override
  bool operator ==(Object other) =>
      other is LogAusschnitt &&
      other.eintraege == eintraege &&
      listEquals(other.filter, filter) &&
      listEquals(other.zeilen, zeilen);

  @override
  int get hashCode =>
      Object.hash(eintraege, Object.hashAll(filter), zeilen.length);
}
