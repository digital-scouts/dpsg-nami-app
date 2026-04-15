import 'mitglied.dart';

enum PendingPersonUpdateStatus { queued, needsResolution }

enum MemberResolutionProblemType { conflict, validation }

enum MemberResolutionCategory { mergeConflict, nonMergeProblem, mixed }

enum MemberResolutionCause {
  overlappingChange,
  serverValidation,
  addressValidation,
  remoteDeletedLocalEdited,
  unknown,
}

enum MemberResolutionTargetType {
  firstName,
  lastName,
  nickname,
  gender,
  birthday,
  primaryEmail,
  phone,
  additionalEmail,
  primaryAddress,
  additionalAddress,
}

enum MemberResolutionSource { manualSave, pendingRetry }

class MemberResolutionTarget {
  const MemberResolutionTarget({
    required this.type,
    this.relationshipId,
    this.fingerprint,
  });

  final MemberResolutionTargetType type;
  final int? relationshipId;
  final String? fingerprint;

  String get storageKey =>
      '${type.name}:${relationshipId ?? fingerprint ?? 'default'}';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'relationship_id': relationshipId,
      'fingerprint': fingerprint,
    };
  }

  factory MemberResolutionTarget.fromJson(Map<String, dynamic> json) {
    return MemberResolutionTarget(
      type: MemberResolutionTargetType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => MemberResolutionTargetType.firstName,
      ),
      relationshipId: _parseInt(json['relationship_id']),
      fingerprint: _trimToNull(json['fingerprint']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MemberResolutionTarget &&
        other.type == type &&
        other.relationshipId == relationshipId &&
        other.fingerprint == fingerprint;
  }

  @override
  int get hashCode => Object.hash(type, relationshipId, fingerprint);
}

class MemberResolutionItem {
  const MemberResolutionItem({
    required this.problemType,
    required this.target,
    required this.message,
    this.cause,
    this.code,
  });

  final MemberResolutionProblemType problemType;
  final MemberResolutionTarget target;
  final String message;
  final MemberResolutionCause? cause;
  final String? code;

  MemberResolutionCause get effectiveCause {
    if (cause != null) {
      return cause!;
    }
    return switch (problemType) {
      MemberResolutionProblemType.conflict =>
        MemberResolutionCause.overlappingChange,
      MemberResolutionProblemType.validation =>
        _defaultValidationCauseForTarget(target),
    };
  }

  String get itemId => '${problemType.name}:${target.storageKey}';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'problem_type': problemType.name,
      'target': target.toJson(),
      'message': message,
      'cause': effectiveCause.name,
      'code': code,
    };
  }

  factory MemberResolutionItem.fromJson(Map<String, dynamic> json) {
    return MemberResolutionItem(
      problemType: MemberResolutionProblemType.values.firstWhere(
        (value) => value.name == json['problem_type'],
        orElse: () => MemberResolutionProblemType.conflict,
      ),
      target: MemberResolutionTarget.fromJson(
        (json['target'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      message: json['message']?.toString() ?? '',
      cause: json['cause'] == null
          ? null
          : MemberResolutionCause.values.firstWhere(
              (value) => value.name == json['cause'],
              orElse: () => MemberResolutionCause.unknown,
            ),
      code: _trimToNull(json['code']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MemberResolutionItem &&
        other.problemType == problemType &&
        other.target == target &&
        other.message == message &&
        other.cause == cause &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(problemType, target, message, cause, code);
}

class MemberResolutionCase {
  const MemberResolutionCase({
    required this.remoteMitglied,
    required this.items,
    required this.source,
  });

  final Mitglied remoteMitglied;
  final List<MemberResolutionItem> items;
  final MemberResolutionSource source;

  Set<MemberResolutionCause> get causes =>
      items.map((item) => item.effectiveCause).toSet();

  bool get hasMergeConflicts =>
      causes.contains(MemberResolutionCause.overlappingChange);

  bool get hasNonMergeProblems =>
      causes.any((cause) => cause != MemberResolutionCause.overlappingChange);

  MemberResolutionCategory get category {
    if (items.isEmpty) {
      return MemberResolutionCategory.nonMergeProblem;
    }
    if (hasMergeConflicts && hasNonMergeProblems) {
      return MemberResolutionCategory.mixed;
    }
    if (hasMergeConflicts) {
      return MemberResolutionCategory.mergeConflict;
    }
    return MemberResolutionCategory.nonMergeProblem;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'remote_mitglied': remoteMitglied.toPeopleListJson(),
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'source': source.name,
    };
  }

  factory MemberResolutionCase.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    return MemberResolutionCase(
      remoteMitglied: Mitglied.fromPeopleListJson(
        (json['remote_mitglied'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      items: itemsJson is List
          ? itemsJson
                .whereType<Map>()
                .map(
                  (item) => MemberResolutionItem.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false)
          : const <MemberResolutionItem>[],
      source: MemberResolutionSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => MemberResolutionSource.manualSave,
      ),
    );
  }
}

class MemberMergePlan {
  const MemberMergePlan({required this.mergedMitglied, required this.items});

  final Mitglied mergedMitglied;
  final List<MemberResolutionItem> items;

  bool get requiresResolution => items.isNotEmpty;
}

class MemberConflictResolver {
  const MemberConflictResolver._();

  static MemberMergePlan resolve({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
  }) {
    final items = <MemberResolutionItem>[];

    String vorname = remoteMitglied.vorname;
    String nachname = remoteMitglied.nachname;
    String? fahrtenname = remoteMitglied.fahrtenname;
    String? gender = remoteMitglied.gender;
    DateTime geburtsdatum = remoteMitglied.geburtsdatum;
    String? primaryEmail = _primaryEmail(remoteMitglied)?.wert;
    MitgliedKontaktAdresse? primaryAddress = remoteMitglied.primaryAddress;

    void mergeScalar<T>({
      required T basisValue,
      required T localValue,
      required T remoteValue,
      required void Function(T value) assignMerged,
      required MemberResolutionTarget target,
      required String message,
    }) {
      final localChanged = localValue != basisValue;
      if (!localChanged) {
        return;
      }
      final remoteChanged = remoteValue != basisValue;
      if (!remoteChanged || localValue == remoteValue) {
        assignMerged(localValue);
        return;
      }
      items.add(
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: target,
          message: message,
        ),
      );
    }

    mergeScalar<String>(
      basisValue: basisMitglied.vorname,
      localValue: zielMitglied.vorname,
      remoteValue: remoteMitglied.vorname,
      assignMerged: (value) => vorname = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.firstName,
      ),
      message: 'Vorname wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<String>(
      basisValue: basisMitglied.nachname,
      localValue: zielMitglied.nachname,
      remoteValue: remoteMitglied.nachname,
      assignMerged: (value) => nachname = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.lastName,
      ),
      message:
          'Nachname wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<String?>(
      basisValue: basisMitglied.fahrtenname,
      localValue: zielMitglied.fahrtenname,
      remoteValue: remoteMitglied.fahrtenname,
      assignMerged: (value) => fahrtenname = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.nickname,
      ),
      message:
          'Fahrtenname wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<String?>(
      basisValue: basisMitglied.gender,
      localValue: zielMitglied.gender,
      remoteValue: remoteMitglied.gender,
      assignMerged: (value) => gender = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.gender,
      ),
      message:
          'Geschlecht wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<DateTime>(
      basisValue: basisMitglied.geburtsdatum,
      localValue: zielMitglied.geburtsdatum,
      remoteValue: remoteMitglied.geburtsdatum,
      assignMerged: (value) => geburtsdatum = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.birthday,
      ),
      message:
          'Geburtsdatum wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<String?>(
      basisValue: _primaryEmail(basisMitglied)?.wert,
      localValue: _primaryEmail(zielMitglied)?.wert,
      remoteValue: _primaryEmail(remoteMitglied)?.wert,
      assignMerged: (value) => primaryEmail = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.primaryEmail,
      ),
      message:
          'Primaere E-Mail wurde lokal und in Hitobito unterschiedlich geaendert.',
    );
    mergeScalar<MitgliedKontaktAdresse?>(
      basisValue: basisMitglied.primaryAddress,
      localValue: zielMitglied.primaryAddress,
      remoteValue: remoteMitglied.primaryAddress,
      assignMerged: (value) => primaryAddress = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.primaryAddress,
      ),
      message:
          'Primaere Adresse wurde lokal und in Hitobito unterschiedlich geaendert.',
    );

    final mergedPhones = _mergePhones(
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
      remoteMitglied: remoteMitglied,
      items: items,
    );
    final mergedAdditionalEmails = _mergeAdditionalEmails(
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
      remoteMitglied: remoteMitglied,
      items: items,
    );
    final mergedAdditionalAddresses = _mergeAdditionalAddresses(
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
      remoteMitglied: remoteMitglied,
      items: items,
    );

    final mergedMitglied = remoteMitglied.copyWith(
      vorname: vorname,
      nachname: nachname,
      fahrtenname: fahrtenname,
      fahrtennameLoeschen: fahrtenname == null,
      gender: gender,
      genderLoeschen: gender == null,
      geburtsdatum: geburtsdatum,
      telefonnummern: mergedPhones,
      emailAdressen: _buildEmailList(
        primaryEmail: primaryEmail,
        additionalEmails: mergedAdditionalEmails,
      ),
      adressen: _buildAddressList(
        primaryAddress: primaryAddress,
        additionalAddresses: mergedAdditionalAddresses,
      ),
    );

    return MemberMergePlan(mergedMitglied: mergedMitglied, items: items);
  }

  static List<MitgliedKontaktTelefon> _mergePhones({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    final merged = <MitgliedKontaktTelefon>[];
    final basisById = {
      for (final item in basisMitglied.telefonnummern)
        if ((item.phoneNumberId ?? 0) > 0) item.phoneNumberId!: item,
    };
    final localById = {
      for (final item in zielMitglied.telefonnummern)
        if ((item.phoneNumberId ?? 0) > 0) item.phoneNumberId!: item,
    };
    final remoteById = {
      for (final item in remoteMitglied.telefonnummern)
        if ((item.phoneNumberId ?? 0) > 0) item.phoneNumberId!: item,
    };
    final ids = <int>{...basisById.keys, ...localById.keys, ...remoteById.keys};
    for (final id in ids) {
      final basis = basisById[id];
      final local = localById[id];
      final remote = remoteById[id];
      final localChanged = local != basis;
      if (!localChanged) {
        if (remote != null) {
          merged.add(remote);
        }
        continue;
      }
      final remoteChanged = remote != basis;
      if (!remoteChanged || local == remote) {
        if (local != null) {
          merged.add(local);
        }
        continue;
      }
      items.add(
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.phone,
            relationshipId: id,
          ),
          message:
              'Telefonnummer wurde lokal und in Hitobito unterschiedlich geaendert.',
        ),
      );
      if (remote != null) {
        merged.add(remote);
      }
    }
    for (final local in zielMitglied.telefonnummern.where(
      (item) => (item.phoneNumberId ?? 0) <= 0,
    )) {
      merged.add(local);
    }
    for (final remote in remoteMitglied.telefonnummern.where(
      (item) => (item.phoneNumberId ?? 0) <= 0,
    )) {
      merged.add(remote);
    }
    return merged;
  }

  static List<MitgliedKontaktEmail> _mergeAdditionalEmails({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    final merged = <MitgliedKontaktEmail>[];
    final basisEmails = _additionalEmails(basisMitglied);
    final localEmails = _additionalEmails(zielMitglied);
    final remoteEmails = _additionalEmails(remoteMitglied);
    final basisById = {
      for (final item in basisEmails)
        if ((item.additionalEmailId ?? 0) > 0) item.additionalEmailId!: item,
    };
    final localById = {
      for (final item in localEmails)
        if ((item.additionalEmailId ?? 0) > 0) item.additionalEmailId!: item,
    };
    final remoteById = {
      for (final item in remoteEmails)
        if ((item.additionalEmailId ?? 0) > 0) item.additionalEmailId!: item,
    };
    final ids = <int>{...basisById.keys, ...localById.keys, ...remoteById.keys};
    for (final id in ids) {
      final basis = basisById[id];
      final local = localById[id];
      final remote = remoteById[id];
      final localChanged = local != basis;
      if (!localChanged) {
        if (remote != null) {
          merged.add(remote);
        }
        continue;
      }
      final remoteChanged = remote != basis;
      if (!remoteChanged || local == remote) {
        if (local != null) {
          merged.add(local);
        }
        continue;
      }
      items.add(
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.additionalEmail,
            relationshipId: id,
          ),
          message:
              'Zusaetzliche E-Mail wurde lokal und in Hitobito unterschiedlich geaendert.',
        ),
      );
      if (remote != null) {
        merged.add(remote);
      }
    }
    for (final local in localEmails.where(
      (item) => (item.additionalEmailId ?? 0) <= 0,
    )) {
      merged.add(local);
    }
    for (final remote in remoteEmails.where(
      (item) => (item.additionalEmailId ?? 0) <= 0,
    )) {
      merged.add(remote);
    }
    return merged;
  }

  static List<MitgliedKontaktAdresse> _mergeAdditionalAddresses({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    final merged = <MitgliedKontaktAdresse>[];
    final basisAddresses = _additionalAddresses(basisMitglied);
    final localAddresses = _additionalAddresses(zielMitglied);
    final remoteAddresses = _additionalAddresses(remoteMitglied);
    final basisById = {
      for (final item in basisAddresses)
        if ((item.additionalAddressId ?? 0) > 0)
          item.additionalAddressId!: item,
    };
    final localById = {
      for (final item in localAddresses)
        if ((item.additionalAddressId ?? 0) > 0)
          item.additionalAddressId!: item,
    };
    final remoteById = {
      for (final item in remoteAddresses)
        if ((item.additionalAddressId ?? 0) > 0)
          item.additionalAddressId!: item,
    };
    final ids = <int>{...basisById.keys, ...localById.keys, ...remoteById.keys};
    for (final id in ids) {
      final basis = basisById[id];
      final local = localById[id];
      final remote = remoteById[id];
      final localChanged = local != basis;
      if (!localChanged) {
        if (remote != null) {
          merged.add(remote);
        }
        continue;
      }
      final remoteChanged = remote != basis;
      if (!remoteChanged || local == remote) {
        if (local != null) {
          merged.add(local);
        }
        continue;
      }
      items.add(
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.additionalAddress,
            relationshipId: id,
          ),
          message:
              'Zusatzadresse wurde lokal und in Hitobito unterschiedlich geaendert.',
        ),
      );
      if (remote != null) {
        merged.add(remote);
      }
    }
    for (final local in localAddresses.where(
      (item) => (item.additionalAddressId ?? 0) <= 0,
    )) {
      merged.add(local);
    }
    for (final remote in remoteAddresses.where(
      (item) => (item.additionalAddressId ?? 0) <= 0,
    )) {
      merged.add(remote);
    }
    return merged;
  }

  static List<MitgliedKontaktEmail> _buildEmailList({
    required String? primaryEmail,
    required List<MitgliedKontaktEmail> additionalEmails,
  }) {
    final list = <MitgliedKontaktEmail>[];
    final normalizedPrimary = _trimToNull(primaryEmail);
    if (normalizedPrimary != null) {
      list.add(
        MitgliedKontaktEmail(
          wert: normalizedPrimary,
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
      );
    }
    list.addAll(additionalEmails);
    return list;
  }

  static List<MitgliedKontaktAdresse> _buildAddressList({
    required MitgliedKontaktAdresse? primaryAddress,
    required List<MitgliedKontaktAdresse> additionalAddresses,
  }) {
    final list = <MitgliedKontaktAdresse>[];
    if (primaryAddress != null && !primaryAddress.istLeer) {
      list.add(primaryAddress);
    }
    list.addAll(additionalAddresses.where((address) => !address.istLeer));
    return list;
  }

  static MitgliedKontaktEmail? _primaryEmail(Mitglied mitglied) {
    for (final email in mitglied.emailAdressen) {
      if (email.istPrimaer) {
        return email;
      }
    }
    return null;
  }

  static List<MitgliedKontaktEmail> _additionalEmails(Mitglied mitglied) {
    return mitglied.emailAdressen
        .where((email) => !email.istPrimaer)
        .toList(growable: false);
  }

  static List<MitgliedKontaktAdresse> _additionalAddresses(Mitglied mitglied) {
    if (mitglied.adressen.length <= 1) {
      return const <MitgliedKontaktAdresse>[];
    }
    return mitglied.adressen.skip(1).toList(growable: false);
  }
}

int? _parseInt(Object? rawValue) {
  if (rawValue == null) {
    return null;
  }
  if (rawValue is int) {
    return rawValue;
  }
  return int.tryParse(rawValue.toString());
}

String? _trimToNull(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

MemberResolutionCause _defaultValidationCauseForTarget(
  MemberResolutionTarget target,
) {
  return switch (target.type) {
    MemberResolutionTargetType.primaryAddress ||
    MemberResolutionTargetType.additionalAddress =>
      MemberResolutionCause.addressValidation,
    _ => MemberResolutionCause.serverValidation,
  };
}
