import '../../domain/member/mitglied.dart';

class HitobitoPersonResource {
  const HitobitoPersonResource({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickname,
    this.primaryGroupId,
    this.membershipNumber,
  }) : assert(id > 0);

  final int id;
  final String firstName;
  final String lastName;
  final String? nickname;
  final int? primaryGroupId;
  final int? membershipNumber;

  String get memberId {
    final currentMembershipNumber = membershipNumber;
    if (currentMembershipNumber != null && currentMembershipNumber > 0) {
      return currentMembershipNumber.toString();
    }
    return id.toString();
  }

  Mitglied toMitglied() {
    return Mitglied.peopleListItem(
      mitgliedsnummer: memberId,
      vorname: firstName,
      nachname: lastName,
      fahrtenname: nickname,
    );
  }
}
