import '../member/mitglied.dart';
import 'arbeitskontext.dart';

class ArbeitskontextMitgliedsZuordnung {
  const ArbeitskontextMitgliedsZuordnung({
    required this.mitgliedsnummer,
    required this.gruppenId,
    this.rollenTyp,
    this.rollenLabel,
  }) : assert(mitgliedsnummer != ''),
       assert(gruppenId > 0);

  final String mitgliedsnummer;
  final int gruppenId;
  final String? rollenTyp;
  final String? rollenLabel;

  String? get displayRollenLabel {
    final trimmedRoleLabel = rollenLabel?.trim();
    if (trimmedRoleLabel != null && trimmedRoleLabel.isNotEmpty) {
      return trimmedRoleLabel;
    }

    final trimmedRoleType = rollenTyp?.trim();
    if (trimmedRoleType == null || trimmedRoleType.isEmpty) {
      return null;
    }

    final segments = trimmedRoleType
        .split('::')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return null;
    }

    return segments.last;
  }

  ArbeitskontextMitgliedsZuordnung copyWith({
    String? mitgliedsnummer,
    int? gruppenId,
    String? rollenTyp,
    String? rollenLabel,
    bool rollenTypLoeschen = false,
    bool rollenLabelLoeschen = false,
  }) => ArbeitskontextMitgliedsZuordnung(
    mitgliedsnummer: mitgliedsnummer ?? this.mitgliedsnummer,
    gruppenId: gruppenId ?? this.gruppenId,
    rollenTyp: rollenTypLoeschen ? null : rollenTyp ?? this.rollenTyp,
    rollenLabel: rollenLabelLoeschen ? null : rollenLabel ?? this.rollenLabel,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextMitgliedsZuordnung &&
        other.mitgliedsnummer == mitgliedsnummer &&
        other.gruppenId == gruppenId &&
        other.rollenTyp == rollenTyp &&
        other.rollenLabel == rollenLabel;
  }

  @override
  int get hashCode =>
      Object.hash(mitgliedsnummer, gruppenId, rollenTyp, rollenLabel);

  @override
  String toString() {
    return 'ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: $mitgliedsnummer, gruppenId: $gruppenId, rollenTyp: $rollenTyp, rollenLabel: $rollenLabel)';
  }
}

class ArbeitskontextGruppe {
  const ArbeitskontextGruppe({
    required this.id,
    required this.name,
    required this.layerId,
  }) : assert(id > 0),
       assert(name != ''),
       assert(layerId > 0);

  final int id;
  final String name;
  final int layerId;

  ArbeitskontextGruppe copyWith({int? id, String? name, int? layerId}) =>
      ArbeitskontextGruppe(
        id: id ?? this.id,
        name: name ?? this.name,
        layerId: layerId ?? this.layerId,
      );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextGruppe &&
        other.id == id &&
        other.name == name &&
        other.layerId == layerId;
  }

  @override
  int get hashCode => Object.hash(id, name, layerId);

  @override
  String toString() {
    return 'ArbeitskontextGruppe(id: $id, name: $name, layerId: $layerId)';
  }
}

/// Lesbarer Bestand eines aktiven Arbeitskontexts.
///
/// Dieser Read-Model-Schnitt ist bewusst noch klein: Personen und lesbare
/// Nicht-Layer-Gruppen fuer genau einen aktiven Layer.
class ArbeitskontextReadModel {
  ArbeitskontextReadModel({
    required this.arbeitskontext,
    Iterable<Mitglied> mitglieder = const <Mitglied>[],
    Iterable<ArbeitskontextGruppe> gruppen = const <ArbeitskontextGruppe>[],
    Iterable<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen =
        const <ArbeitskontextMitgliedsZuordnung>[],
  }) : mitglieder = List.unmodifiable(_normalizeMitglieder(mitglieder)),
       gruppen = List.unmodifiable(
         _normalizeGruppen(
           aktiverLayerId: arbeitskontext.aktiverLayer.id,
           gruppen: gruppen,
         ),
       ),
       mitgliedsZuordnungen = List.unmodifiable(
         _normalizeMitgliedsZuordnungen(
           aktiverLayerId: arbeitskontext.aktiverLayer.id,
           gruppen: gruppen,
           mitgliedsZuordnungen: mitgliedsZuordnungen,
         ),
       );

  final Arbeitskontext arbeitskontext;
  final List<Mitglied> mitglieder;
  final List<ArbeitskontextGruppe> gruppen;
  final List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen;

  bool get hatMitglieder => mitglieder.isNotEmpty;
  bool get hatGruppen => gruppen.isNotEmpty;
  bool get hatMitgliedsZuordnungen => mitgliedsZuordnungen.isNotEmpty;

  Mitglied? findeMitglied(String mitgliedsnummer) {
    for (final mitglied in mitglieder) {
      if (mitglied.mitgliedsnummer == mitgliedsnummer) {
        return mitglied;
      }
    }
    return null;
  }

  ArbeitskontextGruppe? findeGruppe(int gruppenId) {
    for (final gruppe in gruppen) {
      if (gruppe.id == gruppenId) {
        return gruppe;
      }
    }
    return null;
  }

  List<ArbeitskontextMitgliedsZuordnung> findeMitgliedsZuordnungen(
    String mitgliedsnummer,
  ) {
    return mitgliedsZuordnungen
        .where((zuordnung) => zuordnung.mitgliedsnummer == mitgliedsnummer)
        .toList(growable: false);
  }

  ArbeitskontextReadModel copyWith({
    Arbeitskontext? arbeitskontext,
    Iterable<Mitglied>? mitglieder,
    Iterable<ArbeitskontextGruppe>? gruppen,
    Iterable<ArbeitskontextMitgliedsZuordnung>? mitgliedsZuordnungen,
  }) => ArbeitskontextReadModel(
    arbeitskontext: arbeitskontext ?? this.arbeitskontext,
    mitglieder: mitglieder ?? this.mitglieder,
    gruppen: gruppen ?? this.gruppen,
    mitgliedsZuordnungen: mitgliedsZuordnungen ?? this.mitgliedsZuordnungen,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextReadModel &&
        other.arbeitskontext == arbeitskontext &&
        _listEquals(other.mitglieder, mitglieder) &&
        _listEquals(other.gruppen, gruppen) &&
        _listEquals(other.mitgliedsZuordnungen, mitgliedsZuordnungen);
  }

  @override
  int get hashCode => Object.hash(
    arbeitskontext,
    Object.hashAll(mitglieder),
    Object.hashAll(gruppen),
    Object.hashAll(mitgliedsZuordnungen),
  );

  @override
  String toString() {
    return 'ArbeitskontextReadModel(arbeitskontext: $arbeitskontext, mitglieder: $mitglieder, gruppen: $gruppen, mitgliedsZuordnungen: $mitgliedsZuordnungen)';
  }

  static List<Mitglied> _normalizeMitglieder(Iterable<Mitglied> mitglieder) {
    final ids = <String>{};
    final result = <Mitglied>[];

    for (final mitglied in mitglieder) {
      if (!ids.add(mitglied.mitgliedsnummer)) {
        continue;
      }
      result.add(mitglied);
    }

    return result;
  }

  static List<ArbeitskontextGruppe> _normalizeGruppen({
    required int aktiverLayerId,
    required Iterable<ArbeitskontextGruppe> gruppen,
  }) {
    final ids = <int>{};
    final result = <ArbeitskontextGruppe>[];

    for (final gruppe in gruppen) {
      assert(
        gruppe.layerId == aktiverLayerId,
        'Gruppen im ArbeitskontextReadModel muessen zum aktiven Layer gehoeren.',
      );
      if (!ids.add(gruppe.id)) {
        continue;
      }
      result.add(gruppe);
    }

    return result;
  }

  static List<ArbeitskontextMitgliedsZuordnung> _normalizeMitgliedsZuordnungen({
    required int aktiverLayerId,
    required Iterable<ArbeitskontextGruppe> gruppen,
    required Iterable<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen,
  }) {
    final gruppenIds = gruppen
        .where((gruppe) => gruppe.layerId == aktiverLayerId)
        .map((gruppe) => gruppe.id)
        .toSet();
    final ids = <String>{};
    final result = <ArbeitskontextMitgliedsZuordnung>[];

    for (final zuordnung in mitgliedsZuordnungen) {
      if (!gruppenIds.contains(zuordnung.gruppenId)) {
        continue;
      }

      final key = [
        zuordnung.mitgliedsnummer,
        zuordnung.gruppenId.toString(),
        zuordnung.rollenTyp ?? '',
        zuordnung.rollenLabel ?? '',
      ].join('|');
      if (!ids.add(key)) {
        continue;
      }

      result.add(zuordnung);
    }

    return result;
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
