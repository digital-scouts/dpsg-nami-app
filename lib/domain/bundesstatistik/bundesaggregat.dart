/// Bundesaggregat laut API-Vertrag `server/spec/bundesaggregat.md`.
class KennzahlAggregat {
  const KennzahlAggregat({
    required this.summe,
    required this.stammAnzahl,
    required this.median,
  });

  /// `null`, wenn der Server die Kennzahl wegen zu weniger Staemme unterdrueckt.
  final num? summe;
  final int stammAnzahl;
  final num? median;

  bool get istUnterdrueckt => summe == null;

  double? get durchschnitt {
    final value = summe;
    if (value == null || stammAnzahl <= 0) {
      return null;
    }
    return value / stammAnzahl;
  }

  factory KennzahlAggregat.fromJson(Map<String, dynamic> json) =>
      KennzahlAggregat(
        summe: json['sum'] as num?,
        stammAnzahl: (json['stamm_count'] as num?)?.toInt() ?? 0,
        median: json['median'] as num?,
      );
}

/// Kennzahl ueber alle Gruppen einer Stufe: Median je Gruppe, Durchschnitt
/// ueber die Gruppen. Unterdrueckt wird nach Anzahl der Staemme.
class GruppenKennzahlAggregat extends KennzahlAggregat {
  const GruppenKennzahlAggregat({
    required super.summe,
    required super.stammAnzahl,
    required super.median,
    required this.gruppenAnzahl,
  });

  final int gruppenAnzahl;

  @override
  double? get durchschnitt {
    final value = summe;
    if (value == null || gruppenAnzahl <= 0) {
      return null;
    }
    return value / gruppenAnzahl;
  }

  factory GruppenKennzahlAggregat.fromJson(Map<String, dynamic> json) =>
      GruppenKennzahlAggregat(
        summe: json['sum'] as num?,
        stammAnzahl: (json['stamm_count'] as num?)?.toInt() ?? 0,
        median: json['median'] as num?,
        gruppenAnzahl: (json['gruppen_count'] as num?)?.toInt() ?? 0,
      );
}

/// Gruppengroesse einer Stufe (`gruppen_je_stufe` im Aggregat).
class StufenGruppenAggregat {
  const StufenGruppenAggregat({
    required this.gruppenAnzahl,
    required this.stammAnzahl,
    required this.gruppenProStamm,
    required this.mitglieder,
    required this.leitende,
  });

  final int gruppenAnzahl;
  final int stammAnzahl;
  final KennzahlAggregat gruppenProStamm;

  /// Je Geschlechterfeld, z. B. `gesamt`, `weiblich`.
  final Map<String, GruppenKennzahlAggregat> mitglieder;
  final Map<String, GruppenKennzahlAggregat> leitende;

  factory StufenGruppenAggregat.fromJson(Map<String, dynamic> json) {
    Map<String, GruppenKennzahlAggregat> verteilung(Object? value) => {
      if (value is Map<String, dynamic>)
        for (final entry in value.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: GruppenKennzahlAggregat.fromJson(
              entry.value as Map<String, dynamic>,
            ),
    };
    final proStamm = json['gruppen_pro_stamm'];
    return StufenGruppenAggregat(
      gruppenAnzahl: (json['gruppen_count'] as num?)?.toInt() ?? 0,
      stammAnzahl: (json['stamm_count'] as num?)?.toInt() ?? 0,
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
    required this.teilnehmendeStaemme,
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
  final int teilnehmendeStaemme;
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
      teilnehmendeStaemme:
          (json['participating_stamm_count'] as num?)?.toInt() ?? 0,
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
      if (value.containsKey('stamm_count')) {
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
