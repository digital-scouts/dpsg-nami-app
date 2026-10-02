import 'package:collection/collection.dart';

import '../member_filters/member_custom_filter.dart';
import '../taetigkeit/stufe.dart';
import 'statistik_kachel_typen.dart';

enum EigeneKachelDarstellung { zahl, nachStufe }

/// Eine Kachel auf dem Überblick. Dieselbe Kachel darf mehrfach vorkommen,
/// [id] unterscheidet die Einträge.
class KachelEintrag {
  const KachelEintrag({
    required this.id,
    required this.typId,
    required this.groesse,
    this.eigeneKachelId,
  });

  final String id;
  final String typId;
  final KachelGroesse groesse;

  /// Nur bei [StatistikKachelTypen.eigene]: welche eigene Kachel gemeint ist.
  final String? eigeneKachelId;

  KachelEintrag copyWith({KachelGroesse? groesse}) => KachelEintrag(
    id: id,
    typId: typId,
    groesse: groesse ?? this.groesse,
    eigeneKachelId: eigeneKachelId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'typ': typId,
    'groesse': groesse.schluessel,
    if (eigeneKachelId != null) 'eigeneKachelId': eigeneKachelId,
  };

  @override
  bool operator ==(Object other) =>
      other is KachelEintrag &&
      other.id == id &&
      other.typId == typId &&
      other.groesse == groesse &&
      other.eigeneKachelId == eigeneKachelId;

  @override
  int get hashCode => Object.hash(id, typId, groesse, eigeneKachelId);
}

/// Eine selbst angelegte Zählkachel. Der Filter ist eine Kopie, damit das
/// Löschen eines Filters in der Mitgliederliste die Kachel nicht zerstört.
class EigeneKachel {
  const EigeneKachel({
    required this.id,
    required this.titel,
    required this.filter,
    this.darstellung = EigeneKachelDarstellung.zahl,
    this.ziel,
    this.zielText,
  });

  final String id;
  final String titel;
  final MemberCustomFilterGroup filter;
  final EigeneKachelDarstellung darstellung;

  /// Anzahl der Plätze, z. B. 3 für den Stammesvorstand; `null` = ohne Ziel.
  final int? ziel;

  /// Wort hinter „3 von 3 …“, z. B. „besetzt“.
  final String? zielText;

  EigeneKachel copyWith({
    String? titel,
    MemberCustomFilterGroup? filter,
    EigeneKachelDarstellung? darstellung,
    int? ziel,
    bool zielLoeschen = false,
    String? zielText,
  }) => EigeneKachel(
    id: id,
    titel: titel ?? this.titel,
    filter: filter ?? this.filter,
    darstellung: darstellung ?? this.darstellung,
    ziel: zielLoeschen ? null : ziel ?? this.ziel,
    zielText: zielText ?? this.zielText,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titel': titel,
    'filter': filter.toJson(),
    'darstellung': darstellung.name,
    if (ziel != null) 'ziel': ziel,
    if (zielText != null) 'zielText': zielText,
  };

  static EigeneKachel? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final titel = json['titel'];
    final filter = json['filter'];
    if (id is! String || id.isEmpty || titel is! String || titel.isEmpty) {
      return null;
    }
    if (filter is! Map<String, dynamic>) return null;
    final MemberCustomFilterGroup gruppe;
    try {
      gruppe = MemberCustomFilterGroup.fromJson(filter);
    } catch (_) {
      return null;
    }
    final ziel = json['ziel'];
    return EigeneKachel(
      id: id,
      titel: titel,
      filter: gruppe,
      darstellung: EigeneKachelDarstellung.values.firstWhere(
        (d) => d.name == json['darstellung'],
        orElse: () => EigeneKachelDarstellung.zahl,
      ),
      ziel: ziel is int && ziel > 0 ? ziel : null,
      zielText: json['zielText'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EigeneKachel &&
      other.id == id &&
      other.titel == titel &&
      other.filter == filter &&
      other.darstellung == darstellung &&
      other.ziel == ziel &&
      other.zielText == zielText;

  @override
  int get hashCode =>
      Object.hash(id, titel, filter, darstellung, ziel, zielText);
}

/// Zielwerte eines Stamms. Leer bedeutet: keine Zielmarken anzeigen.
class StatistikZielwerte {
  const StatistikZielwerte({this.neuProJahr, this.gruppeMax = const {}});

  static const StatistikZielwerte leer = StatistikZielwerte();

  /// Wie viele Neue pro Jahr der Stamm aufnehmen möchte.
  final int? neuProJahr;

  /// Höchste gewünschte Gruppengröße je Stufe.
  final Map<Stufe, int> gruppeMax;

  /// Zielwert einer Stufe insgesamt: Höchstgröße × Anzahl ihrer Gruppen.
  int? zielFuerStufe(Stufe stufe, int anzahlGruppen) {
    final max = gruppeMax[stufe];
    if (max == null) return null;
    return max * (anzahlGruppen < 1 ? 1 : anzahlGruppen);
  }

  Map<String, dynamic> toJson() => {
    if (neuProJahr != null) 'neuProJahr': neuProJahr,
    'gruppeMax': {
      for (final eintrag in gruppeMax.entries) eintrag.key.name: eintrag.value,
    },
  };

  static StatistikZielwerte fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return leer;
    final neu = json['neuProJahr'];
    final rohMax = json['gruppeMax'];
    final gruppeMax = <Stufe, int>{};
    if (rohMax is Map) {
      for (final eintrag in rohMax.entries) {
        final stufe = Stufe.values.firstWhereOrNull(
          (s) => s.name == eintrag.key,
        );
        final wert = eintrag.value;
        if (stufe != null &&
            stufe != Stufe.leitung &&
            wert is int &&
            wert > 0) {
          gruppeMax[stufe] = wert;
        }
      }
    }
    return StatistikZielwerte(
      neuProJahr: neu is int && neu > 0 ? neu : null,
      gruppeMax: Map.unmodifiable(gruppeMax),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatistikZielwerte &&
      other.neuProJahr == neuProJahr &&
      const MapEquality<Stufe, int>().equals(other.gruppeMax, gruppeMax);

  @override
  int get hashCode => Object.hash(
    neuProJahr,
    Object.hashAllUnordered(
      gruppeMax.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Statistik-Einstellungen eines Stamms (Layers).
class StatistikKachelEinstellungen {
  const StatistikKachelEinstellungen({
    this.ueberblick = standardUeberblick,
    this.stufenSichtbar = true,
    this.entwicklungSichtbar = true,
    this.eigeneKacheln = const [],
    this.ziele = StatistikZielwerte.leer,
  });

  static const int version = 1;

  static const List<KachelEintrag> standardUeberblick = [
    KachelEintrag(
      id: 'standard-gruppen',
      typId: StatistikKachelTypen.gruppen,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'standard-stufenwechsel',
      typId: StatistikKachelTypen.stufenwechsel,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-bindung',
      typId: StatistikKachelTypen.bindung,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-geschlecht',
      typId: StatistikKachelTypen.geschlecht,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-konfession',
      typId: StatistikKachelTypen.konfession,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-standorte',
      typId: StatistikKachelTypen.standorte,
      groesse: KachelGroesse.breit,
    ),
  ];

  /// Standard für Personen, die nur einzelne Gruppen sehen: dieselben Kacheln
  /// wie im Stamm, ergänzt um die Altersstruktur in 2×1.
  static const List<KachelEintrag> standardUeberblickTeilsicht = [
    KachelEintrag(
      id: 'standard-gruppen',
      typId: StatistikKachelTypen.gruppen,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'standard-altersstruktur',
      typId: StatistikKachelTypen.altersstruktur,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'standard-stufenwechsel',
      typId: StatistikKachelTypen.stufenwechsel,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-bindung',
      typId: StatistikKachelTypen.bindung,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-geschlecht',
      typId: StatistikKachelTypen.geschlecht,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-konfession',
      typId: StatistikKachelTypen.konfession,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'standard-standorte',
      typId: StatistikKachelTypen.standorte,
      groesse: KachelGroesse.breit,
    ),
  ];

  /// Feste Belegung der Detailseite einer Gruppe.
  static const List<KachelEintrag> gruppenDetail = [
    KachelEintrag(
      id: 'gruppe-personen',
      typId: StatistikKachelTypen.personen,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'gruppe-altersstruktur',
      typId: StatistikKachelTypen.altersstruktur,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'gruppe-stufenwechsel',
      typId: StatistikKachelTypen.stufenwechsel,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'gruppe-bindung',
      typId: StatistikKachelTypen.bindung,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'gruppe-geschlecht',
      typId: StatistikKachelTypen.geschlecht,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'gruppe-konfession',
      typId: StatistikKachelTypen.konfession,
      groesse: KachelGroesse.klein,
    ),
    KachelEintrag(
      id: 'gruppe-standorte',
      typId: StatistikKachelTypen.standorte,
      groesse: KachelGroesse.gross,
    ),
  ];

  /// Ob noch die unveränderte Standardbelegung gilt (nichts gespeichert).
  bool get hatStandardUeberblick => identical(ueberblick, standardUeberblick);

  /// Fest zusammengestellte Kacheln des Tabs „Stufen“.
  static const List<KachelEintrag> stufenTab = [
    KachelEintrag(
      id: 'stufen-gruppen',
      typId: StatistikKachelTypen.gruppen,
      groesse: KachelGroesse.gross,
    ),
    KachelEintrag(
      id: 'stufen-altersstruktur',
      typId: StatistikKachelTypen.altersstruktur,
      groesse: KachelGroesse.gross,
    ),
    KachelEintrag(
      id: 'stufen-alter-in-zahlen',
      typId: StatistikKachelTypen.alterInZahlen,
      groesse: KachelGroesse.breit,
    ),
  ];

  /// Fest zusammengestellte Kacheln des Tabs „Entwicklung“.
  static const List<KachelEintrag> entwicklungTab = [
    KachelEintrag(
      id: 'entwicklung-stufenwechsel',
      typId: StatistikKachelTypen.stufenwechsel,
      groesse: KachelGroesse.gross,
    ),
    KachelEintrag(
      id: 'entwicklung-bindung',
      typId: StatistikKachelTypen.bindung,
      groesse: KachelGroesse.breit,
    ),
    KachelEintrag(
      id: 'entwicklung-verlauf',
      typId: StatistikKachelTypen.verlauf,
      groesse: KachelGroesse.breit,
    ),
  ];

  final List<KachelEintrag> ueberblick;
  final bool stufenSichtbar;
  final bool entwicklungSichtbar;
  final List<EigeneKachel> eigeneKacheln;
  final StatistikZielwerte ziele;

  EigeneKachel? eigeneKachel(String? id) =>
      eigeneKacheln.firstWhereOrNull((k) => k.id == id);

  StatistikKachelEinstellungen copyWith({
    List<KachelEintrag>? ueberblick,
    bool? stufenSichtbar,
    bool? entwicklungSichtbar,
    List<EigeneKachel>? eigeneKacheln,
    StatistikZielwerte? ziele,
  }) => StatistikKachelEinstellungen(
    ueberblick: ueberblick ?? this.ueberblick,
    stufenSichtbar: stufenSichtbar ?? this.stufenSichtbar,
    entwicklungSichtbar: entwicklungSichtbar ?? this.entwicklungSichtbar,
    eigeneKacheln: eigeneKacheln ?? this.eigeneKacheln,
    ziele: ziele ?? this.ziele,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'ueberblick': ueberblick.map((e) => e.toJson()).toList(growable: false),
    'stufenSichtbar': stufenSichtbar,
    'entwicklungSichtbar': entwicklungSichtbar,
    'eigeneKacheln': eigeneKacheln
        .map((k) => k.toJson())
        .toList(growable: false),
    'ziele': ziele.toJson(),
  };

  /// Liest gespeicherte Einstellungen tolerant: unbekannte Kacheln fallen
  /// weg, unzulässige Größen rasten auf eine erlaubte Größe ein, fehlende
  /// Teile werden durch Standardwerte ersetzt.
  static StatistikKachelEinstellungen fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const StatistikKachelEinstellungen();
    }
    final eigene = <EigeneKachel>[];
    final rohEigene = json['eigeneKacheln'];
    if (rohEigene is List) {
      final ids = <String>{};
      for (final roh in rohEigene) {
        final kachel = EigeneKachel.fromJson(roh);
        if (kachel != null && ids.add(kachel.id)) eigene.add(kachel);
      }
    }
    final eigeneIds = eigene.map((k) => k.id).toSet();

    final rohUeberblick = json['ueberblick'];
    final List<KachelEintrag> ueberblick;
    if (rohUeberblick is List) {
      final eintraege = <KachelEintrag>[];
      final ids = <String>{};
      for (final roh in rohUeberblick) {
        final eintrag = _eintragAusJson(roh, eigeneIds);
        if (eintrag != null && ids.add(eintrag.id)) eintraege.add(eintrag);
      }
      ueberblick = List.unmodifiable(eintraege);
    } else {
      ueberblick = standardUeberblick;
    }

    return StatistikKachelEinstellungen(
      ueberblick: ueberblick,
      stufenSichtbar: json['stufenSichtbar'] as bool? ?? true,
      entwicklungSichtbar: json['entwicklungSichtbar'] as bool? ?? true,
      eigeneKacheln: List.unmodifiable(eigene),
      ziele: StatistikZielwerte.fromJson(json['ziele']),
    );
  }

  static KachelEintrag? _eintragAusJson(Object? roh, Set<String> eigeneIds) {
    if (roh is! Map<String, dynamic>) return null;
    final id = roh['id'];
    final typId = roh['typ'];
    if (id is! String || id.isEmpty || typId is! String) return null;
    if (!StatistikKachelTypen.istBekannt(typId)) return null;
    final eigeneId = roh['eigeneKachelId'] as String?;
    if (typId == StatistikKachelTypen.eigene && !eigeneIds.contains(eigeneId)) {
      return null;
    }
    final erlaubt = StatistikKachelTypen.groessenFuer(typId);
    final gelesen = KachelGroesse.ausSchluessel(roh['groesse'] as String?);
    final groesse = gelesen != null && erlaubt.contains(gelesen)
        ? gelesen
        : naechsteErlaubteGroesse(
            erlaubt,
            gelesen?.spalten ?? 1,
            gelesen?.zeilen ?? 1,
          );
    return KachelEintrag(
      id: id,
      typId: typId,
      groesse: groesse,
      eigeneKachelId: typId == StatistikKachelTypen.eigene ? eigeneId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatistikKachelEinstellungen &&
      const ListEquality<KachelEintrag>().equals(
        other.ueberblick,
        ueberblick,
      ) &&
      other.stufenSichtbar == stufenSichtbar &&
      other.entwicklungSichtbar == entwicklungSichtbar &&
      const ListEquality<EigeneKachel>().equals(
        other.eigeneKacheln,
        eigeneKacheln,
      ) &&
      other.ziele == ziele;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(ueberblick),
    stufenSichtbar,
    entwicklungSichtbar,
    Object.hashAll(eigeneKacheln),
    ziele,
  );
}

abstract class StatistikKachelRepository {
  Future<StatistikKachelEinstellungen> loadForLayer(int layerId);
  Future<void> saveForLayer(
    int layerId,
    StatistikKachelEinstellungen einstellungen,
  );
}
