import 'member_resolution.dart';
import 'mitglied.dart';

class PendingPersonUpdate {
  const PendingPersonUpdate({
    required this.entryId,
    required this.personId,
    required this.mitgliedsnummer,
    required this.displayName,
    required this.basisMitglied,
    required this.zielMitglied,
    required this.queuedAt,
    this.status = PendingPersonUpdateStatus.queued,
    this.resolutionCase,
    this.attemptCount = 0,
    this.lastAttemptAt,
  }) : assert(entryId != ''),
       assert(personId > 0),
       assert(mitgliedsnummer != '');

  final String entryId;
  final int personId;
  final String mitgliedsnummer;
  final String displayName;
  final Mitglied basisMitglied;
  final Mitglied zielMitglied;
  final DateTime queuedAt;
  final PendingPersonUpdateStatus status;
  final MemberResolutionCase? resolutionCase;
  final int attemptCount;
  final DateTime? lastAttemptAt;

  DateTime? get basisUpdatedAt => basisMitglied.updatedAt;
  bool get needsResolution =>
      status == PendingPersonUpdateStatus.needsResolution;

  PendingPersonUpdate copyWith({
    String? entryId,
    int? personId,
    String? mitgliedsnummer,
    String? displayName,
    Mitglied? basisMitglied,
    Mitglied? zielMitglied,
    DateTime? queuedAt,
    PendingPersonUpdateStatus? status,
    MemberResolutionCase? resolutionCase,
    int? attemptCount,
    DateTime? lastAttemptAt,
    bool resolutionCaseLoeschen = false,
    bool lastAttemptAtLoeschen = false,
  }) => PendingPersonUpdate(
    entryId: entryId ?? this.entryId,
    personId: personId ?? this.personId,
    mitgliedsnummer: mitgliedsnummer ?? this.mitgliedsnummer,
    displayName: displayName ?? this.displayName,
    basisMitglied: basisMitglied ?? this.basisMitglied,
    zielMitglied: zielMitglied ?? this.zielMitglied,
    queuedAt: queuedAt ?? this.queuedAt,
    status: status ?? this.status,
    resolutionCase: resolutionCaseLoeschen
        ? null
        : resolutionCase ?? this.resolutionCase,
    attemptCount: attemptCount ?? this.attemptCount,
    lastAttemptAt: lastAttemptAtLoeschen
        ? null
        : lastAttemptAt ?? this.lastAttemptAt,
  );

  PendingPersonUpdate markAttempted(DateTime attemptedAt) {
    return copyWith(attemptCount: attemptCount + 1, lastAttemptAt: attemptedAt);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entry_id': entryId,
      'person_id': personId,
      'mitgliedsnummer': mitgliedsnummer,
      'display_name': displayName,
      'basis_mitglied': basisMitglied.toPeopleListJson(),
      'ziel_mitglied': zielMitglied.toPeopleListJson(),
      'queued_at': queuedAt.toIso8601String(),
      'status': status.name,
      'resolution_case': resolutionCase?.toJson(),
      'attempt_count': attemptCount,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
    };
  }

  factory PendingPersonUpdate.fromJson(Map<String, dynamic> json) {
    final basisJson = json['basis_mitglied'];
    final zielJson = json['ziel_mitglied'];
    if (basisJson is! Map<String, dynamic> ||
        zielJson is! Map<String, dynamic>) {
      throw const FormatException('Pending-Personenupdate ist unvollstaendig.');
    }
    return PendingPersonUpdate(
      entryId: json['entry_id']?.toString() ?? '',
      personId: _parseInt(json['person_id']) ?? 0,
      mitgliedsnummer: json['mitgliedsnummer']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      basisMitglied: Mitglied.fromPeopleListJson(basisJson),
      zielMitglied: Mitglied.fromPeopleListJson(zielJson),
      queuedAt:
          _parseDateTime(json['queued_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: PendingPersonUpdateStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => PendingPersonUpdateStatus.queued,
      ),
      resolutionCase: (json['resolution_case'] as Map?) != null
          ? MemberResolutionCase.fromJson(
              (json['resolution_case'] as Map).cast<String, dynamic>(),
            )
          : null,
      attemptCount: _parseInt(json['attempt_count']) ?? 0,
      lastAttemptAt: _parseDateTime(json['last_attempt_at']),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int? _parseInt(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return int.tryParse(raw);
}
