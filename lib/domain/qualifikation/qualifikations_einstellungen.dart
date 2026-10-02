import 'personenkreis.dart';

/// Schluessel einer Qualifikationsart in den Einstellungen: `efz` oder
/// `hitobito:<qualification_kind_id>`. App-weit, nicht pro Arbeitskontext.
class QualifikationsSchluessel {
  const QualifikationsSchluessel._();

  static const efz = 'efz';

  static String hitobito(int artId) => 'hitobito:$artId';
}

enum ErinnerungVonWem { alle, ich }

/// Erinnerung vor dem Ablauf einer Qualifikation. [tageVorher] gilt auch als
/// Warnschwelle fuer „demnaechst faellig“.
class QualifikationsErinnerung {
  const QualifikationsErinnerung({
    this.aktiv = true,
    this.tageVorher = standardTage,
    this.vonWem = ErinnerungVonWem.ich,
  });

  static const standardTage = 90;
  static const minTage = 1;
  static const maxTage = 365;

  final bool aktiv;
  final int tageVorher;

  /// Bei Ablaeufen von allen im Personenkreis oder nur bei den eigenen.
  final ErinnerungVonWem vonWem;

  /// Ohne aktive Erinnerung bleibt die Warnschwelle beim Standard.
  int get warnschwelleTage => aktiv ? tageVorher : standardTage;

  QualifikationsErinnerung copyWith({
    bool? aktiv,
    int? tageVorher,
    ErinnerungVonWem? vonWem,
  }) => QualifikationsErinnerung(
    aktiv: aktiv ?? this.aktiv,
    tageVorher: (tageVorher ?? this.tageVorher).clamp(minTage, maxTage),
    vonWem: vonWem ?? this.vonWem,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aktiv': aktiv,
    'tage_vorher': tageVorher,
    'von_wem': vonWem.name,
  };

  static QualifikationsErinnerung? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final tage = int.tryParse(json['tage_vorher']?.toString() ?? '');
    return QualifikationsErinnerung(
      aktiv: json['aktiv'] != false,
      tageVorher: (tage ?? standardTage).clamp(minTage, maxTage),
      vonWem: json['von_wem'] == ErinnerungVonWem.alle.name
          ? ErinnerungVonWem.alle
          : ErinnerungVonWem.ich,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QualifikationsErinnerung &&
      other.aktiv == aktiv &&
      other.tageVorher == tageVorher &&
      other.vonWem == vonWem;

  @override
  int get hashCode => Object.hash(aktiv, tageVorher, vonWem);
}

/// Gespeicherte Einstellung einer Art. `null` heisst jeweils: Vorgabe aus
/// [QualifikationsVorgaben].
class ArtEinstellung {
  const ArtEinstellung({this.angezeigt, this.personenkreis, this.erinnerung});

  final bool? angezeigt;
  final Personenkreis? personenkreis;
  final QualifikationsErinnerung? erinnerung;

  ArtEinstellung copyWith({
    bool? angezeigt,
    Personenkreis? personenkreis,
    QualifikationsErinnerung? erinnerung,
  }) => ArtEinstellung(
    angezeigt: angezeigt ?? this.angezeigt,
    personenkreis: personenkreis ?? this.personenkreis,
    erinnerung: erinnerung ?? this.erinnerung,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (angezeigt != null) 'angezeigt': angezeigt,
    if (personenkreis != null) 'personenkreis': personenkreis!.toJson(),
    if (erinnerung != null) 'erinnerung': erinnerung!.toJson(),
  };

  static ArtEinstellung fromJson(Object? json) {
    if (json is! Map) {
      return const ArtEinstellung();
    }
    final angezeigt = json['angezeigt'];
    return ArtEinstellung(
      angezeigt: angezeigt is bool ? angezeigt : null,
      personenkreis: Personenkreis.fromJson(json['personenkreis']),
      erinnerung: QualifikationsErinnerung.fromJson(json['erinnerung']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ArtEinstellung &&
      other.angezeigt == angezeigt &&
      other.personenkreis == personenkreis &&
      other.erinnerung == erinnerung;

  @override
  int get hashCode => Object.hash(angezeigt, personenkreis, erinnerung);
}

/// Erinnerung an die eigenen Qualifikationen (Benachrichtigungen), frei fuer
/// alle Nutzer. [arten] `null` heisst: die Vorgaben.
class EigeneQualifikationsErinnerung {
  const EigeneQualifikationsErinnerung({
    this.aktiv = true,
    this.arten,
    this.tageVorher = QualifikationsErinnerung.standardTage,
  });

  final bool aktiv;
  final Set<String>? arten;
  final int tageVorher;

  EigeneQualifikationsErinnerung copyWith({
    bool? aktiv,
    Set<String>? arten,
    int? tageVorher,
  }) => EigeneQualifikationsErinnerung(
    aktiv: aktiv ?? this.aktiv,
    arten: arten ?? this.arten,
    tageVorher: (tageVorher ?? this.tageVorher).clamp(
      QualifikationsErinnerung.minTage,
      QualifikationsErinnerung.maxTage,
    ),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aktiv': aktiv,
    if (arten != null) 'arten': (arten!.toList()..sort()),
    'tage_vorher': tageVorher,
  };

  static EigeneQualifikationsErinnerung fromJson(Object? json) {
    if (json is! Map) {
      return const EigeneQualifikationsErinnerung();
    }
    final arten = json['arten'];
    final tage = int.tryParse(json['tage_vorher']?.toString() ?? '');
    return EigeneQualifikationsErinnerung(
      aktiv: json['aktiv'] != false,
      arten: arten is List ? arten.map((e) => e.toString()).toSet() : null,
      tageVorher: (tage ?? QualifikationsErinnerung.standardTage).clamp(
        QualifikationsErinnerung.minTage,
        QualifikationsErinnerung.maxTage,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EigeneQualifikationsErinnerung &&
      other.aktiv == aktiv &&
      _setGleich(other.arten, arten) &&
      other.tageVorher == tageVorher;

  @override
  int get hashCode => Object.hash(
    aktiv,
    arten == null ? null : Object.hashAllUnordered(arten!),
    tageVorher,
  );
}

/// App-weite Einstellungen der Qualifikationen-Uebersicht. Einstellungen zu
/// Arten, die im aktuellen Kontext niemand hat, bleiben erhalten.
class QualifikationsEinstellungen {
  const QualifikationsEinstellungen({
    this.arten = const <String, ArtEinstellung>{},
    this.reihenfolge = const <String>[],
    this.eigene = const EigeneQualifikationsErinnerung(),
  });

  final Map<String, ArtEinstellung> arten;

  /// Gewuenschte Reihenfolge der angezeigten Arten; fehlende Schluessel
  /// folgen nach den Vorgaben.
  final List<String> reihenfolge;
  final EigeneQualifikationsErinnerung eigene;

  ArtEinstellung art(String schluessel) =>
      arten[schluessel] ?? const ArtEinstellung();

  QualifikationsEinstellungen mitArt(
    String schluessel,
    ArtEinstellung einstellung,
  ) => QualifikationsEinstellungen(
    arten: <String, ArtEinstellung>{...arten, schluessel: einstellung},
    reihenfolge: reihenfolge,
    eigene: eigene,
  );

  QualifikationsEinstellungen copyWith({
    List<String>? reihenfolge,
    EigeneQualifikationsErinnerung? eigene,
  }) => QualifikationsEinstellungen(
    arten: arten,
    reihenfolge: reihenfolge ?? this.reihenfolge,
    eigene: eigene ?? this.eigene,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'arten': <String, dynamic>{
      for (final eintrag in arten.entries) eintrag.key: eintrag.value.toJson(),
    },
    'reihenfolge': reihenfolge,
    'eigene': eigene.toJson(),
  };

  static QualifikationsEinstellungen fromJson(Object? json) {
    if (json is! Map) {
      return const QualifikationsEinstellungen();
    }
    final arten = json['arten'];
    final reihenfolge = json['reihenfolge'];
    return QualifikationsEinstellungen(
      arten: arten is Map
          ? <String, ArtEinstellung>{
              for (final eintrag in arten.entries)
                eintrag.key.toString(): ArtEinstellung.fromJson(eintrag.value),
            }
          : const <String, ArtEinstellung>{},
      reihenfolge: reihenfolge is List
          ? reihenfolge.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      eigene: EigeneQualifikationsErinnerung.fromJson(json['eigene']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! QualifikationsEinstellungen ||
        other.eigene != eigene ||
        other.arten.length != arten.length ||
        other.reihenfolge.length != reihenfolge.length) {
      return false;
    }
    for (var i = 0; i < reihenfolge.length; i++) {
      if (other.reihenfolge[i] != reihenfolge[i]) {
        return false;
      }
    }
    for (final eintrag in arten.entries) {
      if (other.arten[eintrag.key] != eintrag.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      arten.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(reihenfolge),
    eigene,
  );
}

/// Vorgaben fuer Arten ohne gespeicherte Einstellung. Praevention und Erste
/// Hilfe werden ueber den Namen erkannt, weil die Art-IDs je Instanz
/// verschieden sind.
class QualifikationsVorgaben {
  const QualifikationsVorgaben._();

  static bool istPraevention(String label) =>
      label.toLowerCase().contains('präventi') ||
      label.toLowerCase().contains('praeventi');

  static bool istErsteHilfe(String label) {
    final klein = label.toLowerCase();
    return klein.contains('erste hilfe') ||
        klein.contains('erste-hilfe') ||
        klein.contains('ersthelfer');
  }

  static bool istVorgabe(String schluessel, String label) =>
      schluessel == QualifikationsSchluessel.efz ||
      istPraevention(label) ||
      istErsteHilfe(label);

  /// Rang fuer die Standard-Reihenfolge: EFZ, Praevention, Erste Hilfe,
  /// danach alle anderen.
  static int rang(String schluessel, String label) {
    if (schluessel == QualifikationsSchluessel.efz) {
      return 0;
    }
    if (istPraevention(label)) {
      return 1;
    }
    if (istErsteHilfe(label)) {
      return 2;
    }
    return 3;
  }

  static Personenkreis personenkreis(String schluessel, String label) =>
      schluessel == QualifikationsSchluessel.efz || istPraevention(label)
      ? Personenkreis.leitungOderAmt
      : Personenkreis.leitung;

  static QualifikationsErinnerung erinnerung(String schluessel, String label) =>
      QualifikationsErinnerung(
        vonWem:
            schluessel == QualifikationsSchluessel.efz || istPraevention(label)
            ? ErinnerungVonWem.alle
            : ErinnerungVonWem.ich,
      );
}

bool _setGleich(Set<String>? a, Set<String>? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return a.length == b.length && a.containsAll(b);
}
