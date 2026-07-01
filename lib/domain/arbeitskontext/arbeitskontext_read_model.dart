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
    this.parentId,
    this.displayName,
    this.shortName,
    this.description,
    this.gruppenTyp,
    this.selfRegistrationUrl,
    this.selfRegistrationRequireAdultConsent = false,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : assert(id > 0),
       assert(name != ''),
       assert(layerId > 0);

  final int id;
  final String name;
  final int layerId;
  final int? parentId;
  final String? displayName;
  final String? shortName;
  final String? description;
  final String? gruppenTyp;
  final String? selfRegistrationUrl;
  final bool selfRegistrationRequireAdultConsent;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  String get anzeigename {
    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      return trimmedDisplayName;
    }

    final trimmedShortName = shortName?.trim();
    if (trimmedShortName != null && trimmedShortName.isNotEmpty) {
      return trimmedShortName;
    }

    return name;
  }

  ArbeitskontextGruppe copyWith({
    int? id,
    String? name,
    int? layerId,
    int? parentId,
    String? displayName,
    String? shortName,
    String? description,
    String? gruppenTyp,
    String? selfRegistrationUrl,
    bool? selfRegistrationRequireAdultConsent,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool displayNameLoeschen = false,
    bool shortNameLoeschen = false,
    bool descriptionLoeschen = false,
    bool gruppenTypLoeschen = false,
    bool selfRegistrationUrlLoeschen = false,
    bool archivedAtLoeschen = false,
    bool createdAtLoeschen = false,
    bool updatedAtLoeschen = false,
    bool deletedAtLoeschen = false,
  }) => ArbeitskontextGruppe(
    id: id ?? this.id,
    name: name ?? this.name,
    layerId: layerId ?? this.layerId,
    parentId: parentId ?? this.parentId,
    displayName: displayNameLoeschen ? null : displayName ?? this.displayName,
    shortName: shortNameLoeschen ? null : shortName ?? this.shortName,
    description: descriptionLoeschen ? null : description ?? this.description,
    gruppenTyp: gruppenTypLoeschen ? null : gruppenTyp ?? this.gruppenTyp,
    selfRegistrationUrl: selfRegistrationUrlLoeschen
        ? null
        : selfRegistrationUrl ?? this.selfRegistrationUrl,
    selfRegistrationRequireAdultConsent:
        selfRegistrationRequireAdultConsent ??
        this.selfRegistrationRequireAdultConsent,
    archivedAt: archivedAtLoeschen ? null : archivedAt ?? this.archivedAt,
    createdAt: createdAtLoeschen ? null : createdAt ?? this.createdAt,
    updatedAt: updatedAtLoeschen ? null : updatedAt ?? this.updatedAt,
    deletedAt: deletedAtLoeschen ? null : deletedAt ?? this.deletedAt,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextGruppe &&
        other.id == id &&
        other.name == name &&
        other.layerId == layerId &&
        other.parentId == parentId &&
        other.displayName == displayName &&
        other.shortName == shortName &&
        other.description == description &&
        other.gruppenTyp == gruppenTyp &&
        other.selfRegistrationUrl == selfRegistrationUrl &&
        other.selfRegistrationRequireAdultConsent ==
            selfRegistrationRequireAdultConsent &&
        other.archivedAt == archivedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    layerId,
    parentId,
    displayName,
    shortName,
    description,
    gruppenTyp,
    selfRegistrationUrl,
    selfRegistrationRequireAdultConsent,
    archivedAt,
    createdAt,
    updatedAt,
    deletedAt,
  );

  @override
  String toString() {
    return 'ArbeitskontextGruppe(id: $id, name: $name, layerId: $layerId, parentId: $parentId, displayName: $displayName, shortName: $shortName, description: $description, gruppenTyp: $gruppenTyp, selfRegistrationUrl: $selfRegistrationUrl, selfRegistrationRequireAdultConsent: $selfRegistrationRequireAdultConsent, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
  }
}

/// Lesbarer Bestand eines aktiven Arbeitskontexts.
///
/// Dieser Read-Model-Schnitt ist bewusst noch klein: Personen und lesbare
/// Nicht-Layer-Gruppen fuer genau einen aktiven Layer.
class ArbeitskontextReadModel {
  ArbeitskontextReadModel({
    required this.arbeitskontext,
    this.rolesSindGeladen = false,
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
  final bool rolesSindGeladen;
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
    bool? rolesSindGeladen,
    Iterable<Mitglied>? mitglieder,
    Iterable<ArbeitskontextGruppe>? gruppen,
    Iterable<ArbeitskontextMitgliedsZuordnung>? mitgliedsZuordnungen,
  }) => ArbeitskontextReadModel(
    arbeitskontext: arbeitskontext ?? this.arbeitskontext,
    rolesSindGeladen: rolesSindGeladen ?? this.rolesSindGeladen,
    mitglieder: mitglieder ?? this.mitglieder,
    gruppen: gruppen ?? this.gruppen,
    mitgliedsZuordnungen: mitgliedsZuordnungen ?? this.mitgliedsZuordnungen,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextReadModel &&
        other.arbeitskontext == arbeitskontext &&
        other.rolesSindGeladen == rolesSindGeladen &&
        _listEquals(other.mitglieder, mitglieder) &&
        _listEquals(other.gruppen, gruppen) &&
        _listEquals(other.mitgliedsZuordnungen, mitgliedsZuordnungen);
  }

  @override
  int get hashCode => Object.hash(
    arbeitskontext,
    rolesSindGeladen,
    Object.hashAll(mitglieder),
    Object.hashAll(gruppen),
    Object.hashAll(mitgliedsZuordnungen),
  );

  @override
  String toString() {
    return 'ArbeitskontextReadModel(arbeitskontext: $arbeitskontext, rolesSindGeladen: $rolesSindGeladen, mitglieder: $mitglieder, gruppen: $gruppen, mitgliedsZuordnungen: $mitgliedsZuordnungen)';
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
