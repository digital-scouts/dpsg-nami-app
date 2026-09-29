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
  pronoun,
  primaryEmail,
  phone,
  additionalEmail,
  primaryAddress,
  additionalAddress,
  bankAccount,
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

  bool get hasMergeConflicts => causes.any(_isMergeConflictCause);

  bool get hasNonMergeProblems =>
      causes.any((cause) => !_isMergeConflictCause(cause));

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

/// Bankverbindung als eine Merge-Einheit, analog zur Hauptadresse.
class MemberBankData {
  const MemberBankData({
    this.accountOwner,
    this.iban,
    this.bic,
    this.bankName,
    this.paymentMethod,
  });

  factory MemberBankData.of(Mitglied mitglied) {
    return MemberBankData(
      accountOwner: _trimToNull(mitglied.bankAccountOwner),
      iban: _trimToNull(mitglied.iban),
      bic: _trimToNull(mitglied.bic),
      bankName: _trimToNull(mitglied.bankName),
      paymentMethod: _trimToNull(mitglied.paymentMethod),
    );
  }

  final String? accountOwner;
  final String? iban;
  final String? bic;
  final String? bankName;
  final String? paymentMethod;

  Mitglied applyTo(Mitglied mitglied) {
    return mitglied.copyWith(
      bankAccountOwner: accountOwner,
      bankAccountOwnerLoeschen: accountOwner == null,
      iban: iban,
      ibanLoeschen: iban == null,
      bic: bic,
      bicLoeschen: bic == null,
      bankName: bankName,
      bankNameLoeschen: bankName == null,
      paymentMethod: paymentMethod,
      paymentMethodLoeschen: paymentMethod == null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MemberBankData &&
        other.accountOwner == accountOwner &&
        other.iban == iban &&
        other.bic == bic &&
        other.bankName == bankName &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode =>
      Object.hash(accountOwner, iban, bic, bankName, paymentMethod);
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
    String? fahrtenname = _trimToNull(remoteMitglied.fahrtenname);
    String? gender = _trimToNull(remoteMitglied.gender);
    DateTime geburtsdatum = remoteMitglied.geburtsdatum;
    String? pronoun = _trimToNull(remoteMitglied.pronoun);
    MemberBankData bankData = MemberBankData.of(remoteMitglied);
    String? primaryEmail = _primaryEmail(remoteMitglied)?.wert;
    MitgliedKontaktAdresse? primaryAddress = _primaryAddressWithoutLabel(
      remoteMitglied,
    );

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
      message: 'Vorname wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<String>(
      basisValue: basisMitglied.nachname,
      localValue: zielMitglied.nachname,
      remoteValue: remoteMitglied.nachname,
      assignMerged: (value) => nachname = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.lastName,
      ),
      message: 'Nachname wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<String?>(
      basisValue: _trimToNull(basisMitglied.fahrtenname),
      localValue: _trimToNull(zielMitglied.fahrtenname),
      remoteValue: _trimToNull(remoteMitglied.fahrtenname),
      assignMerged: (value) => fahrtenname = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.nickname,
      ),
      message:
          'Fahrtenname wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<String?>(
      basisValue: _trimToNull(basisMitglied.gender),
      localValue: _trimToNull(zielMitglied.gender),
      remoteValue: _trimToNull(remoteMitglied.gender),
      assignMerged: (value) => gender = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.gender,
      ),
      message:
          'Geschlecht wurde lokal und in Hitobito unterschiedlich geändert.',
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
          'Geburtsdatum wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<String?>(
      basisValue: _trimToNull(basisMitglied.pronoun),
      localValue: _trimToNull(zielMitglied.pronoun),
      remoteValue: _trimToNull(remoteMitglied.pronoun),
      assignMerged: (value) => pronoun = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.pronoun,
      ),
      message: 'Pronomen wurde lokal und in Hitobito unterschiedlich geändert.',
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
          'Primäre E-Mail wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<MitgliedKontaktAdresse?>(
      basisValue: _primaryAddressWithoutLabel(basisMitglied),
      localValue: _primaryAddressWithoutLabel(zielMitglied),
      remoteValue: _primaryAddressWithoutLabel(remoteMitglied),
      assignMerged: (value) => primaryAddress = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.primaryAddress,
      ),
      message:
          'Primäre Adresse wurde lokal und in Hitobito unterschiedlich geändert.',
    );
    mergeScalar<MemberBankData>(
      basisValue: MemberBankData.of(basisMitglied),
      localValue: MemberBankData.of(zielMitglied),
      remoteValue: MemberBankData.of(remoteMitglied),
      assignMerged: (value) => bankData = value,
      target: const MemberResolutionTarget(
        type: MemberResolutionTargetType.bankAccount,
      ),
      message:
          'Bankverbindung wurde lokal und in Hitobito unterschiedlich geändert.',
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
      pronoun: pronoun,
      pronounLoeschen: pronoun == null,
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

    return MemberMergePlan(
      mergedMitglied: bankData.applyTo(mergedMitglied),
      items: items,
    );
  }

  static List<MitgliedKontaktTelefon> _mergePhones({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    return _mergeRelationships<MitgliedKontaktTelefon>(
      basis: basisMitglied.telefonnummern,
      local: zielMitglied.telefonnummern,
      remote: remoteMitglied.telefonnummern,
      idOf: (item) => item.phoneNumberId,
      withoutId: (item) => item.copyWith(phoneNumberIdLoeschen: true),
      targetType: MemberResolutionTargetType.phone,
      conflictMessage:
          'Telefonnummer wurde lokal und in Hitobito unterschiedlich geändert.',
      remoteDeletedMessage:
          'Telefonnummer wurde lokal geändert, in Hitobito aber gelöscht.',
      items: items,
    );
  }

  static List<MitgliedKontaktEmail> _mergeAdditionalEmails({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    return _mergeRelationships<MitgliedKontaktEmail>(
      basis: _additionalEmails(basisMitglied),
      local: _additionalEmails(zielMitglied),
      remote: _additionalEmails(remoteMitglied),
      idOf: (item) => item.additionalEmailId,
      withoutId: (item) => item.copyWith(additionalEmailIdLoeschen: true),
      targetType: MemberResolutionTargetType.additionalEmail,
      conflictMessage:
          'Zusätzliche E-Mail wurde lokal und in Hitobito unterschiedlich geändert.',
      remoteDeletedMessage:
          'Zusätzliche E-Mail wurde lokal geändert, in Hitobito aber gelöscht.',
      items: items,
    );
  }

  static List<MitgliedKontaktAdresse> _mergeAdditionalAddresses({
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    required Mitglied remoteMitglied,
    required List<MemberResolutionItem> items,
  }) {
    return _mergeRelationships<MitgliedKontaktAdresse>(
      basis: _additionalAddresses(basisMitglied),
      local: _additionalAddresses(zielMitglied),
      remote: _additionalAddresses(remoteMitglied),
      idOf: (item) => item.additionalAddressId,
      withoutId: (item) => item.copyWith(additionalAddressIdLoeschen: true),
      targetType: MemberResolutionTargetType.additionalAddress,
      conflictMessage:
          'Zusatzadresse wurde lokal und in Hitobito unterschiedlich geändert.',
      remoteDeletedMessage:
          'Zusatzadresse wurde lokal geändert, in Hitobito aber gelöscht.',
      items: items,
    );
  }

  /// Drei-Wege-Merge fuer Kontakteintraege.
  ///
  /// Eintraege mit ID werden pro ID verglichen. Eintraege ohne ID (lokal neu
  /// angelegt) werden ueber ihren Inhalt verglichen: lokal entfernte fallen
  /// weg, lokal neue werden nur ergaenzt, wenn der Server denselben Inhalt
  /// nicht schon hat, etwa weil ein frueheres Senden bereits angekommen ist.
  static List<T> _mergeRelationships<T>({
    required List<T> basis,
    required List<T> local,
    required List<T> remote,
    required int? Function(T item) idOf,
    required T Function(T item) withoutId,
    required MemberResolutionTargetType targetType,
    required String conflictMessage,
    required String remoteDeletedMessage,
    required List<MemberResolutionItem> items,
  }) {
    bool hasId(T item) => (idOf(item) ?? 0) > 0;
    Map<int, T> byId(List<T> list) => {
      for (final item in list)
        if (hasId(item)) idOf(item)!: item,
    };

    final merged = <T>[];
    final basisById = byId(basis);
    final localById = byId(local);
    final remoteById = byId(remote);
    final ids = <int>{...basisById.keys, ...localById.keys, ...remoteById.keys};
    for (final id in ids) {
      final basisItem = basisById[id];
      final localItem = localById[id];
      final remoteItem = remoteById[id];
      final localChanged = localItem != basisItem;
      if (!localChanged) {
        if (remoteItem != null) {
          merged.add(remoteItem);
        }
        continue;
      }
      final remoteChanged = remoteItem != basisItem;
      if (!remoteChanged || localItem == remoteItem) {
        if (localItem != null) {
          merged.add(localItem);
        }
        continue;
      }
      final remoteDeleted = remoteItem == null && localItem != null;
      items.add(
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: remoteDeleted
              ? MemberResolutionCause.remoteDeletedLocalEdited
              : MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(type: targetType, relationshipId: id),
          message: remoteDeleted ? remoteDeletedMessage : conflictMessage,
        ),
      );
      if (remoteItem != null) {
        merged.add(remoteItem);
      }
    }

    final basisWithoutId = basis.where((item) => !hasId(item)).toList();
    final localWithoutId = local.where((item) => !hasId(item)).toList();
    for (final remoteItem in remote.where((item) => !hasId(item))) {
      final removedLocally =
          basisWithoutId.contains(remoteItem) &&
          !localWithoutId.contains(remoteItem);
      if (!removedLocally) {
        merged.add(remoteItem);
      }
    }
    for (final localItem in localWithoutId) {
      if (basisWithoutId.contains(localItem)) {
        continue;
      }
      final content = withoutId(localItem);
      if (merged.any((item) => withoutId(item) == content)) {
        continue;
      }
      merged.add(localItem);
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
      list.add(primaryAddress.copyWith(additionalAddressId: 0));
    }
    list.addAll(
      additionalAddresses.where(
        (address) => !address.istLeer && address.additionalAddressId != 0,
      ),
    );
    return list;
  }

  /// Hitobito kennt fuer die eigene Adresse der Person keine Bezeichnung.
  /// Ein lokales Label darf deshalb weder als Aenderung noch als Konflikt
  /// zaehlen.
  static MitgliedKontaktAdresse? _primaryAddressWithoutLabel(
    Mitglied mitglied,
  ) {
    return mitglied.primaryAddress?.copyWith(labelLoeschen: true);
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
    return mitglied.additionalAddresses;
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

bool _isMergeConflictCause(MemberResolutionCause cause) {
  return cause == MemberResolutionCause.overlappingChange ||
      cause == MemberResolutionCause.remoteDeletedLocalEdited;
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
