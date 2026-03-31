import '../member/mitglied.dart';
import 'arbeitskontext.dart';

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
  }) : mitglieder = List.unmodifiable(_normalizeMitglieder(mitglieder)),
       gruppen = List.unmodifiable(
         _normalizeGruppen(
           aktiverLayerId: arbeitskontext.aktiverLayer.id,
           gruppen: gruppen,
         ),
       );

  final Arbeitskontext arbeitskontext;
  final List<Mitglied> mitglieder;
  final List<ArbeitskontextGruppe> gruppen;

  bool get hatMitglieder => mitglieder.isNotEmpty;
  bool get hatGruppen => gruppen.isNotEmpty;

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

  ArbeitskontextReadModel copyWith({
    Arbeitskontext? arbeitskontext,
    Iterable<Mitglied>? mitglieder,
    Iterable<ArbeitskontextGruppe>? gruppen,
  }) => ArbeitskontextReadModel(
    arbeitskontext: arbeitskontext ?? this.arbeitskontext,
    mitglieder: mitglieder ?? this.mitglieder,
    gruppen: gruppen ?? this.gruppen,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextReadModel &&
        other.arbeitskontext == arbeitskontext &&
        _listEquals(other.mitglieder, mitglieder) &&
        _listEquals(other.gruppen, gruppen);
  }

  @override
  int get hashCode => Object.hash(
    arbeitskontext,
    Object.hashAll(mitglieder),
    Object.hashAll(gruppen),
  );

  @override
  String toString() {
    return 'ArbeitskontextReadModel(arbeitskontext: $arbeitskontext, mitglieder: $mitglieder, gruppen: $gruppen)';
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
