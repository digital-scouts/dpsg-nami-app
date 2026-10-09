import 'package:collection/collection.dart';

import '../taetigkeit/stufe.dart';
import 'stamm_statistik.dart';

/// Monatliche Summen eines Stamms für die Kachel „Verlauf“. Es werden nur
/// Anzahlen gespeichert, keine Personen.
class StatistikVerlaufEintrag {
  const StatistikVerlaufEintrag({
    required this.monat,
    required this.personen,
    required this.kinder,
    required this.leitende,
    this.jeStufe = const {},
  });

  /// `yyyy-MM`.
  final String monat;
  final int personen;
  final int kinder;
  final int leitende;

  /// Kinder und Jugendliche je Stufe.
  final Map<Stufe, int> jeStufe;

  static String monatSchluessel(DateTime datum) =>
      '${datum.year.toString().padLeft(4, '0')}-${datum.month.toString().padLeft(2, '0')}';

  factory StatistikVerlaufEintrag.aus(
    StammStatistik statistik,
    DateTime heute,
  ) => StatistikVerlaufEintrag(
    monat: monatSchluessel(heute),
    personen: statistik.personen,
    kinder: statistik.kinder,
    leitende: statistik.leitende,
    jeStufe: {for (final s in statistik.stufen) s.stufe: s.kinder},
  );

  Map<String, dynamic> toJson() => {
    'monat': monat,
    'personen': personen,
    'kinder': kinder,
    'leitende': leitende,
    'jeStufe': {for (final e in jeStufe.entries) e.key.name: e.value},
  };

  static StatistikVerlaufEintrag? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final monat = json['monat'];
    if (monat is! String || !RegExp(r'^\d{4}-\d{2}$').hasMatch(monat)) {
      return null;
    }
    int zahl(Object? wert) => wert is int && wert >= 0 ? wert : 0;
    final jeStufe = <Stufe, int>{};
    final roh = json['jeStufe'];
    if (roh is Map) {
      for (final eintrag in roh.entries) {
        final stufe = Stufe.values.firstWhereOrNull(
          (s) => s.name == eintrag.key,
        );
        if (stufe != null) jeStufe[stufe] = zahl(eintrag.value);
      }
    }
    return StatistikVerlaufEintrag(
      monat: monat,
      personen: zahl(json['personen']),
      kinder: zahl(json['kinder']),
      leitende: zahl(json['leitende']),
      jeStufe: Map.unmodifiable(jeStufe),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatistikVerlaufEintrag &&
      other.monat == monat &&
      other.personen == personen &&
      other.kinder == kinder &&
      other.leitende == leitende &&
      const MapEquality<Stufe, int>().equals(other.jeStufe, jeStufe);

  @override
  int get hashCode => Object.hash(monat, personen, kinder, leitende);
}

abstract class StatistikVerlaufRepository {
  Future<List<StatistikVerlaufEintrag>> loadForLayer(int layerId);
  Future<void> saveForLayer(
    int layerId,
    List<StatistikVerlaufEintrag> eintraege,
  );

  /// Entfernt den Verlauf aller Layer, z. B. beim Abmelden oder
  /// Kontowechsel: Er gehört zu den Daten der angemeldeten Person.
  Future<void> clearAll();
}

/// Hält einmal je Monat die Summen fest; ältere Monate als [maxMonate]
/// fallen weg.
class ZeichneStatistikVerlaufAufUseCase {
  const ZeichneStatistikVerlaufAufUseCase(this._repository);

  static const int maxMonate = 24;

  final StatistikVerlaufRepository _repository;

  /// `true`, wenn ein neuer Monat aufgezeichnet wurde.
  Future<bool> call({
    required int layerId,
    required StammStatistik statistik,
    required DateTime heute,
  }) async {
    final eintraege = await _repository.loadForLayer(layerId);
    final monat = StatistikVerlaufEintrag.monatSchluessel(heute);
    if (eintraege.any((e) => e.monat == monat)) return false;
    final neu = [...eintraege, StatistikVerlaufEintrag.aus(statistik, heute)]
      ..sort((a, b) => a.monat.compareTo(b.monat));
    final behalten = neu.length > maxMonate
        ? neu.sublist(neu.length - maxMonate)
        : neu;
    await _repository.saveForLayer(layerId, List.unmodifiable(behalten));
    return true;
  }
}
