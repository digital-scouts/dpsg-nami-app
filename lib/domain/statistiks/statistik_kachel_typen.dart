/// Größe einer Statistik-Kachel im Raster (Spalten × Zeilen).
enum KachelGroesse {
  klein(1, 1, '1x1'),
  breit(2, 1, '2x1'),
  gross(2, 2, '2x2');

  const KachelGroesse(this.spalten, this.zeilen, this.schluessel);

  final int spalten;
  final int zeilen;

  /// Stabiler Wert für die Speicherung.
  final String schluessel;

  /// Anzeige, z. B. „2×1“.
  String get anzeige => schluessel.replaceAll('x', '×');

  static KachelGroesse? ausSchluessel(String? schluessel) {
    for (final groesse in values) {
      if (groesse.schluessel == schluessel) return groesse;
    }
    return null;
  }
}

/// Die zu [spalten] × [zeilen] nächstgelegene erlaubte Größe; bevorzugt
/// gleiche Breite (wie im Bearbeiten-Prototyp).
KachelGroesse naechsteErlaubteGroesse(
  List<KachelGroesse> erlaubt,
  int spalten,
  int zeilen,
) {
  assert(erlaubt.isNotEmpty);
  KachelGroesse? beste;
  var besterAbstand = double.infinity;
  for (final groesse in erlaubt) {
    final abstand =
        (groesse.spalten - spalten).abs() * 1.1 +
        (groesse.zeilen - zeilen).abs();
    if (abstand < besterAbstand) {
      besterAbstand = abstand;
      beste = groesse;
    }
  }
  return beste ?? erlaubt.first;
}

/// Feste Kacheltypen der Stamm-Statistik und ihre erlaubten Größen.
///
/// Die IDs werden gespeichert und dürfen sich nicht ändern. Titel, Inhalte
/// und Vorschauen liegen in der Präsentationsschicht.
abstract final class StatistikKachelTypen {
  static const String personen = 'personen';
  static const String stufen = 'stufen';
  static const String gruppen = 'gruppen';
  static const String altersstruktur = 'altersstruktur';
  static const String alterInZahlen = 'alterInZahlen';
  static const String stufenwechsel = 'stufenwechsel';
  static const String bindung = 'bindung';
  static const String verlauf = 'verlauf';
  static const String geschlecht = 'geschlecht';
  static const String konfession = 'konfession';
  static const String standorte = 'standorte';

  /// Typ einer eigenen Zählkachel; die Definition kommt aus [EigeneKachel].
  static const String eigene = 'eigene';

  static const Map<String, List<KachelGroesse>> erlaubteGroessen = {
    personen: [KachelGroesse.klein, KachelGroesse.breit],
    stufen: [KachelGroesse.breit],
    gruppen: [KachelGroesse.breit, KachelGroesse.gross],
    altersstruktur: [KachelGroesse.gross],
    alterInZahlen: [KachelGroesse.breit, KachelGroesse.gross],
    stufenwechsel: [
      KachelGroesse.klein,
      KachelGroesse.breit,
      KachelGroesse.gross,
    ],
    bindung: [KachelGroesse.klein, KachelGroesse.breit],
    verlauf: [KachelGroesse.klein, KachelGroesse.breit],
    geschlecht: [KachelGroesse.klein, KachelGroesse.breit],
    konfession: [KachelGroesse.klein, KachelGroesse.breit],
    standorte: [KachelGroesse.breit, KachelGroesse.gross],
    eigene: [KachelGroesse.klein, KachelGroesse.breit],
  };

  static bool istBekannt(String typId) => erlaubteGroessen.containsKey(typId);

  static List<KachelGroesse> groessenFuer(String typId) =>
      erlaubteGroessen[typId] ?? const [KachelGroesse.klein];
}
