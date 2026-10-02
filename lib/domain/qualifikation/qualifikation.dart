/// Qualifikation einer Person aus `/api/qualifications` samt Art
/// (`qualification_kind`).
class Qualifikation {
  const Qualifikation({
    required this.id,
    required this.personId,
    required this.label,
    this.artId,
    this.qualifiedAt,
    this.startAt,
    this.finishAt,
    this.origin,
    this.reaktivierbar = false,
  }) : assert(id > 0),
       assert(personId > 0);

  final int id;
  final int personId;
  final int? artId;
  final String label;
  final DateTime? qualifiedAt;
  final DateTime? startAt;

  /// Ende der Gueltigkeit; `null` bei Qualifikationen ohne Ablauf.
  final DateTime? finishAt;
  final String? origin;

  /// Eine abgelaufene Qualifikation laesst sich durch Fortbildung wieder
  /// aktivieren (`qualification_kind.reactivateable`).
  final bool reaktivierbar;

  /// Datum, ab dem die Qualifikation gilt, fuer Anzeige und Sortierung.
  DateTime? get erworbenAm => qualifiedAt ?? startAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'person_id': personId,
    'art_id': artId,
    'label': label,
    'qualified_at': qualifiedAt?.toIso8601String(),
    'start_at': startAt?.toIso8601String(),
    'finish_at': finishAt?.toIso8601String(),
    'origin': origin,
    'reaktivierbar': reaktivierbar,
  };

  /// Liefert `null` fuer unvollstaendige Eintraege.
  static Qualifikation? fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    final personId = int.tryParse(json['person_id']?.toString() ?? '');
    final label = json['label']?.toString().trim();
    if (id == null ||
        id <= 0 ||
        personId == null ||
        personId <= 0 ||
        label == null ||
        label.isEmpty) {
      return null;
    }
    return Qualifikation(
      id: id,
      personId: personId,
      artId: int.tryParse(json['art_id']?.toString() ?? ''),
      label: label,
      qualifiedAt: DateTime.tryParse(json['qualified_at']?.toString() ?? ''),
      startAt: DateTime.tryParse(json['start_at']?.toString() ?? ''),
      finishAt: DateTime.tryParse(json['finish_at']?.toString() ?? ''),
      origin: json['origin']?.toString(),
      reaktivierbar: json['reaktivierbar'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Qualifikation &&
        other.id == id &&
        other.personId == personId &&
        other.artId == artId &&
        other.label == label &&
        other.qualifiedAt == qualifiedAt &&
        other.startAt == startAt &&
        other.finishAt == finishAt &&
        other.origin == origin &&
        other.reaktivierbar == reaktivierbar;
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    artId,
    label,
    qualifiedAt,
    startAt,
    finishAt,
    origin,
    reaktivierbar,
  );

  @override
  String toString() =>
      'Qualifikation(id: $id, personId: $personId, label: $label, '
      'finishAt: $finishAt)';
}
