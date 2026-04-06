import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/mitglied.dart';

class HitobitoPersonRoleResource {
  const HitobitoPersonRoleResource({
    required this.id,
    required this.groupId,
    this.personId,
    this.createdAt,
    this.updatedAt,
    this.startOn,
    this.endOn,
    this.roleType,
    this.roleName,
    this.roleLabel,
  }) : assert(id > 0),
       assert(groupId > 0);

  final int id;
  final int groupId;
  final int? personId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startOn;
  final DateTime? endOn;
  final String? roleType;
  final String? roleName;
  final String? roleLabel;

  String? get resolvedRoleLabel {
    final trimmedRoleName = roleName?.trim();
    if (trimmedRoleName != null && trimmedRoleName.isNotEmpty) {
      return trimmedRoleName;
    }

    final trimmedRoleLabel = roleLabel?.trim();
    if (trimmedRoleLabel != null && trimmedRoleLabel.isNotEmpty) {
      return trimmedRoleLabel;
    }

    final trimmedRoleType = roleType?.trim();
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

  ArbeitskontextMitgliedsZuordnung toMitgliedsZuordnung({
    required String mitgliedsnummer,
  }) {
    return ArbeitskontextMitgliedsZuordnung(
      mitgliedsnummer: mitgliedsnummer,
      gruppenId: groupId,
      rollenTyp: roleType,
      rollenLabel: resolvedRoleLabel,
    );
  }
}

class HitobitoPersonResource {
  const HitobitoPersonResource({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickname,
    this.primaryGroupId,
    this.membershipNumber,
    this.birthday,
    this.entryDate,
    this.exitDate,
    this.updatedAt,
    this.pronoun,
    this.bankAccountOwner,
    this.iban,
    this.bic,
    this.bankName,
    this.paymentMethod,
    this.telefonnummern = const <MitgliedKontaktTelefon>[],
    this.emailAdressen = const <MitgliedKontaktEmail>[],
    this.adressen = const <MitgliedKontaktAdresse>[],
    this.roles = const <HitobitoPersonRoleResource>[],
  }) : assert(id > 0);

  final int id;
  final String firstName;
  final String lastName;
  final String? nickname;
  final int? primaryGroupId;
  final int? membershipNumber;
  final DateTime? birthday;
  final DateTime? entryDate;
  final DateTime? exitDate;
  final DateTime? updatedAt;
  final String? pronoun;
  final String? bankAccountOwner;
  final String? iban;
  final String? bic;
  final String? bankName;
  final String? paymentMethod;
  final List<MitgliedKontaktTelefon> telefonnummern;
  final List<MitgliedKontaktEmail> emailAdressen;
  final List<MitgliedKontaktAdresse> adressen;
  final List<HitobitoPersonRoleResource> roles;

  String get memberId {
    final currentMembershipNumber = membershipNumber;
    if (currentMembershipNumber != null && currentMembershipNumber > 0) {
      return currentMembershipNumber.toString();
    }
    return id.toString();
  }

  Mitglied toMitglied() {
    final resolvedBirthday = birthday ?? Mitglied.peoplePlaceholderDate;
    final resolvedEntryDate = entryDate ?? Mitglied.peoplePlaceholderDate;
    final resolvedExitDate = exitDate?.add(Duration.zero);

    return Mitglied(
      personId: id,
      mitgliedsnummer: memberId,
      vorname: firstName,
      nachname: lastName,
      fahrtenname: nickname,
      geburtsdatum: resolvedBirthday,
      eintrittsdatum: resolvedEntryDate,
      austrittsdatum: resolvedExitDate,
      updatedAt: updatedAt,
      telefonnummern: telefonnummern,
      emailAdressen: emailAdressen,
      adressen: adressen,
      pronoun: pronoun,
      bankAccountOwner: bankAccountOwner,
      iban: iban,
      bic: bic,
      bankName: bankName,
      paymentMethod: paymentMethod,
    );
  }

  List<ArbeitskontextMitgliedsZuordnung> toMitgliedsZuordnungen() {
    return roles
        .map((role) => role.toMitgliedsZuordnung(mitgliedsnummer: memberId))
        .toList(growable: false);
  }
}
