/// Bundesaggregat laut API-Vertrag `server/spec/bundesaggregat.md`. Der
/// Server liefert nur gerundete Ergebnisse, keine Summen und keine Zahl der
/// Staemme oder Gruppen, damit sich einzelne Staemme nicht zurueckrechnen
/// lassen.
class KennzahlAggregat {
  const KennzahlAggregat({
    required this.durchschnitt,
    required this.median,
    this.anteil,
  });

  /// Je Stamm bzw. bei Gruppenwerten je Gruppe; `null`, wenn der Server die
  /// Kennzahl wegen zu weniger Staemme unterdrueckt.
  final double? durchschnitt;
  final num? median;

  /// Anteil am Feld `gesamt` derselben Verteilung in ganzen Prozent, nur bei
  /// Verteilungen wie Geschlecht oder Altersgruppen.
  final int? anteil;

  bool get istUnterdrueckt => durchschnitt == null && median == null;

  factory KennzahlAggregat.fromJson(Map<String, dynamic> json) =>
      KennzahlAggregat(
        durchschnitt: (json['durchschnitt'] as num?)?.toDouble(),
        median: json['median'] as num?,
        anteil: (json['anteil'] as num?)?.toInt(),
      );
}

/// Gruppengroesse einer Stufe (`gruppen_je_stufe` im Aggregat): Durchschnitt
/// und Median je Gruppe.
class StufenGruppenAggregat {
  const StufenGruppenAggregat({
    required this.gruppenProStamm,
    required this.mitglieder,
    required this.leitende,
  });

  final KennzahlAggregat gruppenProStamm;

  /// Je Geschlechterfeld, z. B. `gesamt`, `weiblich`.
  final Map<String, KennzahlAggregat> mitglieder;
  final Map<String, KennzahlAggregat> leitende;

  factory StufenGruppenAggregat.fromJson(Map<String, dynamic> json) {
    Map<String, KennzahlAggregat> verteilung(Object? value) => {
      if (value is Map<String, dynamic>)
        for (final entry in value.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: KennzahlAggregat.fromJson(
              entry.value as Map<String, dynamic>,
            ),
    };
    final proStamm = json['gruppen_pro_stamm'];
    return StufenGruppenAggregat(
      gruppenProStamm: KennzahlAggregat.fromJson(
        proStamm is Map<String, dynamic> ? proStamm : const {},
      ),
      mitglieder: verteilung(json['mitglieder']),
      leitende: verteilung(json['leitende']),
    );
  }
}

enum BundesaggregatStatus { ok, zuWenigTeilnahme }

class Bundesaggregat {
  const Bundesaggregat({
    required this.status,
    this.teilnehmendeStaemmeUeber,
    required this.mindestAnzahlStaemme,
    required this.hinweis,
    required this.kennzahlen,
    this.gruppenJeStufe = const <String, StufenGruppenAggregat>{},
    this.aggregationsWoche,
    this.erzeugtAm,
    this.datenstandVon,
    this.datenstandBis,
  });

  final BundesaggregatStatus status;

  /// Es nehmen mehr als so viele Staemme teil (Vielfaches von 5, ueber 50
  /// von 10); `null` bei zu wenig Teilnahme.
  final int? teilnehmendeStaemmeUeber;
  final int mindestAnzahlStaemme;
  final String hinweis;

  /// Kennzahlen mit Punkt-Pfad als Schluessel, z. B. `biber.gesamt`.
  final Map<String, KennzahlAggregat> kennzahlen;

  /// Gruppengroesse je Stufe, Schluessel wie im API-Vertrag (`woelflinge` ...).
  final Map<String, StufenGruppenAggregat> gruppenJeStufe;
  final String? aggregationsWoche;
  final DateTime? erzeugtAm;
  final DateTime? datenstandVon;
  final DateTime? datenstandBis;

  KennzahlAggregat? kennzahl(String pfad) => kennzahlen[pfad];

  StufenGruppenAggregat? gruppenDerStufe(String stufenSchluessel) =>
      gruppenJeStufe[stufenSchluessel];

  factory Bundesaggregat.fromJson(Map<String, dynamic> json) {
    final dataAsOf = json['data_as_of'];
    final metrics = json['metrics'];
    final gruppen = json['gruppen_je_stufe'];
    return Bundesaggregat(
      status: json['status'] == 'ok'
          ? BundesaggregatStatus.ok
          : BundesaggregatStatus.zuWenigTeilnahme,
      teilnehmendeStaemmeUeber: (json['teilnehmende_staemme_ueber'] as num?)
          ?.toInt(),
      mindestAnzahlStaemme: (json['min_stamm_count'] as num?)?.toInt() ?? 0,
      hinweis: json['notice']?.toString() ?? '',
      kennzahlen: metrics is Map<String, dynamic>
          ? _flatten(metrics)
          : const <String, KennzahlAggregat>{},
      gruppenJeStufe: gruppen is Map<String, dynamic>
          ? {
              for (final entry in gruppen.entries)
                if (entry.value is Map<String, dynamic>)
                  entry.key: StufenGruppenAggregat.fromJson(
                    entry.value as Map<String, dynamic>,
                  ),
            }
          : const <String, StufenGruppenAggregat>{},
      aggregationsWoche: json['aggregation_week']?.toString(),
      erzeugtAm: _toDateTime(json['generated_at']),
      datenstandVon: dataAsOf is Map<String, dynamic>
          ? _toDateTime(dataAsOf['oldest'])
          : null,
      datenstandBis: dataAsOf is Map<String, dynamic>
          ? _toDateTime(dataAsOf['newest'])
          : null,
    );
  }

  static Map<String, KennzahlAggregat> _flatten(
    Map<String, dynamic> node, [
    String prefix = '',
  ]) {
    final result = <String, KennzahlAggregat>{};
    for (final entry in node.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (value.containsKey('durchschnitt')) {
        result[path] = KennzahlAggregat.fromJson(value);
      } else {
        result.addAll(_flatten(value, path));
      }
    }
    return result;
  }

  static DateTime? _toDateTime(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}
