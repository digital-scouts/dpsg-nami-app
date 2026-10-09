/// Ablauf eines Sicherheitsupdates (#197, `specs/app-update.md`):
/// „Später“ geht zweimal, danach laeuft ein Countdown bis zur Sperre.
library;

/// Gespeicherter Stand der Nachfragen fuer diese Installation.
class SicherheitsUpdateStand {
  const SicherheitsUpdateStand({
    this.aufschuebe = 0,
    this.naechsteAnzeigeAb,
    this.sperreAb,
    this.gesperrt = false,
  });

  static const SicherheitsUpdateStand leer = SicherheitsUpdateStand();

  final int aufschuebe;
  final DateTime? naechsteAnzeigeAb;
  final DateTime? sperreAb;
  final bool gesperrt;

  bool get istLeer =>
      aufschuebe == 0 &&
      naechsteAnzeigeAb == null &&
      sperreAb == null &&
      !gesperrt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aufschuebe': aufschuebe,
    if (naechsteAnzeigeAb != null)
      'naechste_anzeige_ab': naechsteAnzeigeAb!.toIso8601String(),
    if (sperreAb != null) 'sperre_ab': sperreAb!.toIso8601String(),
    'gesperrt': gesperrt,
  };

  factory SicherheitsUpdateStand.fromJson(Map<String, dynamic> json) {
    DateTime? zeit(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '');
    final aufschuebe = json['aufschuebe'];
    return SicherheitsUpdateStand(
      aufschuebe: aufschuebe is int ? aufschuebe : 0,
      naechsteAnzeigeAb: zeit('naechste_anzeige_ab'),
      sperreAb: zeit('sperre_ab'),
      gesperrt: json['gesperrt'] == true,
    );
  }
}

enum SicherheitsUpdateLageArt {
  /// Kein Sicherheitsupdate noetig.
  keine,

  /// Nachfrage zeigen.
  nachfrage,

  /// Nachfrage erst ab [SicherheitsUpdateLage.ab] wieder zeigen.
  warten,

  /// Banner mit Restzeit bis [SicherheitsUpdateLage.ab].
  countdown,

  /// App ist bis zum Update gesperrt.
  gesperrt,
}

class SicherheitsUpdateLage {
  const SicherheitsUpdateLage._(
    this.art, {
    this.verbleibendeAufschuebe = 0,
    this.ab,
  });

  static const SicherheitsUpdateLage keine = SicherheitsUpdateLage._(
    SicherheitsUpdateLageArt.keine,
  );
  static const SicherheitsUpdateLage gesperrt = SicherheitsUpdateLage._(
    SicherheitsUpdateLageArt.gesperrt,
  );

  final SicherheitsUpdateLageArt art;
  final int verbleibendeAufschuebe;

  /// Naechste Anzeige ([SicherheitsUpdateLageArt.warten]) oder Beginn der
  /// Sperre ([SicherheitsUpdateLageArt.countdown]).
  final DateTime? ab;
}

/// Reine Regel ohne Seiteneffekte.
class SicherheitsUpdateRegel {
  const SicherheitsUpdateRegel();

  static const int maxAufschuebe = 2;
  static const Duration abstand = Duration(hours: 3);

  SicherheitsUpdateLage lage(
    SicherheitsUpdateStand stand, {
    required DateTime now,
  }) {
    if (stand.gesperrt) {
      return SicherheitsUpdateLage.gesperrt;
    }
    if (stand.aufschuebe >= maxAufschuebe) {
      final sperreAb = _hoechstensAbstandEntfernt(stand.sperreAb, now);
      if (!now.isBefore(sperreAb)) {
        return SicherheitsUpdateLage.gesperrt;
      }
      return SicherheitsUpdateLage._(
        SicherheitsUpdateLageArt.countdown,
        ab: sperreAb,
      );
    }
    final verbleibend = maxAufschuebe - stand.aufschuebe;
    final naechste = stand.naechsteAnzeigeAb;
    // Liegt der Zeitpunkt weiter als der Abstand in der Zukunft, wurde die
    // Uhr zurueckgestellt: dann sofort nachfragen.
    if (naechste == null ||
        !now.isBefore(naechste) ||
        naechste.difference(now) > abstand) {
      return SicherheitsUpdateLage._(
        SicherheitsUpdateLageArt.nachfrage,
        verbleibendeAufschuebe: verbleibend,
      );
    }
    return SicherheitsUpdateLage._(
      SicherheitsUpdateLageArt.warten,
      verbleibendeAufschuebe: verbleibend,
      ab: naechste,
    );
  }

  /// „Später“: Nach dem letzten erlaubten Aufschub beginnt der Countdown.
  SicherheitsUpdateStand spaeter(
    SicherheitsUpdateStand stand, {
    required DateTime now,
  }) {
    final aufschuebe = stand.aufschuebe + 1;
    return SicherheitsUpdateStand(
      aufschuebe: aufschuebe,
      naechsteAnzeigeAb: now.add(abstand),
      sperreAb: aufschuebe >= maxAufschuebe ? now.add(abstand) : null,
    );
  }

  /// Uebernimmt den Stand mit Sperre, sobald sie faellig ist.
  SicherheitsUpdateStand mitSperreWennFaellig(
    SicherheitsUpdateStand stand, {
    required DateTime now,
  }) {
    if (stand.gesperrt ||
        lage(stand, now: now).art != SicherheitsUpdateLageArt.gesperrt) {
      return stand;
    }
    return SicherheitsUpdateStand(
      aufschuebe: stand.aufschuebe,
      naechsteAnzeigeAb: stand.naechsteAnzeigeAb,
      sperreAb: stand.sperreAb,
      gesperrt: true,
    );
  }

  DateTime _hoechstensAbstandEntfernt(DateTime? zeitpunkt, DateTime now) {
    if (zeitpunkt == null) {
      return now;
    }
    final spaetestens = now.add(abstand);
    return zeitpunkt.isAfter(spaetestens) ? spaetestens : zeitpunkt;
  }
}
