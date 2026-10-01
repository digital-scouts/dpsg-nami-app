/// Was zuletzt fuer einen Stamm gesendet wurde.
class StammSendestand {
  const StammSendestand({this.am, this.snapshotJson});

  /// `null` nach neuen Installations-Credentials: Der Stamm muss erneut
  /// senden, der zuletzt geteilte Payload bleibt sichtbar.
  final DateTime? am;

  /// Exakt der zuletzt gesendete Payload, damit sichtbar bleibt, was geteilt wurde.
  final String? snapshotJson;

  Map<String, Object?> toJson() => <String, Object?>{
    'am': am?.toUtc().toIso8601String(),
    'snapshot': snapshotJson,
  };

  factory StammSendestand.fromJson(Map<String, dynamic> json) =>
      StammSendestand(
        am: DateTime.tryParse(json['am']?.toString() ?? ''),
        snapshotJson: json['snapshot']?.toString(),
      );
}

/// Lokal gespeicherter Stand der Teilnahme an der bundesweiten Statistik.
///
/// Die Einwilligung gilt je Stamm und nur fuer die Person, die sie erteilt
/// hat: Wer mehrere Staemme sieht, gibt jeden einzeln frei.
class BundesstatistikTeilnahme {
  const BundesstatistikTeilnahme({
    this.einwilligungFuer,
    this.einwilligungen = const <String, DateTime>{},
    this.sendestaende = const <String, StammSendestand>{},
  });

  static const BundesstatistikTeilnahme leer = BundesstatistikTeilnahme();

  /// Hitobito-Personen-ID, fuer die die Einwilligungen erteilt wurden. Eine
  /// Einwilligung gilt nie fuer eine andere Person am selben Geraet.
  final String? einwilligungFuer;

  /// Stamm-ID → Zeitpunkt der Einwilligung.
  final Map<String, DateTime> einwilligungen;

  /// Stamm-ID → zuletzt gesendeter Stand.
  final Map<String, StammSendestand> sendestaende;

  bool hatEinwilligungFuer(String personId, String stammId) =>
      einwilligungFuer == personId && einwilligungen.containsKey(stammId);

  DateTime? einwilligungAm(String personId, String stammId) =>
      einwilligungFuer == personId ? einwilligungen[stammId] : null;

  /// Juengstes Senden ueber alle Staemme; Grundlage fuer das Lesen der
  /// Bundeswerte, das der Server an die Installation knuepft.
  DateTime? get zuletztGesendetAm {
    DateTime? juengstes;
    for (final stand in sendestaende.values) {
      final am = stand.am;
      if (am != null && (juengstes == null || am.isAfter(juengstes))) {
        juengstes = am;
      }
    }
    return juengstes;
  }

  BundesstatistikTeilnahme mitEinwilligung(
    String personId,
    String stammId,
    DateTime am,
  ) => BundesstatistikTeilnahme(
    einwilligungFuer: personId,
    // Einwilligungen einer anderen Person gelten nicht weiter.
    einwilligungen: <String, DateTime>{
      if (einwilligungFuer == personId) ...einwilligungen,
      stammId: am,
    },
    sendestaende: sendestaende,
  );

  BundesstatistikTeilnahme ohneEinwilligung(String stammId) =>
      BundesstatistikTeilnahme(
        einwilligungFuer: einwilligungFuer,
        einwilligungen: Map<String, DateTime>.of(einwilligungen)
          ..remove(stammId),
        sendestaende: sendestaende,
      );

  BundesstatistikTeilnahme mitGesendetemSnapshot({
    required DateTime am,
    required String stammId,
    required String snapshotJson,
  }) => BundesstatistikTeilnahme(
    einwilligungFuer: einwilligungFuer,
    einwilligungen: einwilligungen,
    sendestaende: <String, StammSendestand>{
      ...sendestaende,
      stammId: StammSendestand(am: am, snapshotJson: snapshotJson),
    },
  );

  /// Nach neuen Credentials muss erneut gesendet werden, bevor gelesen werden darf.
  BundesstatistikTeilnahme ohneSendestand() => BundesstatistikTeilnahme(
    einwilligungFuer: einwilligungFuer,
    einwilligungen: einwilligungen,
    sendestaende: <String, StammSendestand>{
      for (final entry in sendestaende.entries)
        entry.key: StammSendestand(snapshotJson: entry.value.snapshotJson),
    },
  );
}

abstract class BundesstatistikTeilnahmeRepository {
  Future<BundesstatistikTeilnahme> load();
  Future<void> save(BundesstatistikTeilnahme teilnahme);
}
