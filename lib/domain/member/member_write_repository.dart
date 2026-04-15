import 'mitglied.dart';

class MemberWriteException implements Exception {
  const MemberWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemberWriteFieldValidationError {
  const MemberWriteFieldValidationError({
    required this.message,
    this.pointer,
    this.attribute,
    this.relationshipName,
    this.relationshipAttribute,
    this.relationshipType,
    this.relationshipId,
    this.code,
  });

  final String message;
  final String? pointer;
  final String? attribute;
  final String? relationshipName;
  final String? relationshipAttribute;
  final String? relationshipType;
  final int? relationshipId;
  final String? code;

  String? get effectiveAttribute => relationshipAttribute ?? attribute;

  bool get isPhoneNumberField =>
      relationshipName == 'phone_numbers' && effectiveAttribute == 'number';

  @override
  bool operator ==(Object other) {
    return other is MemberWriteFieldValidationError &&
        other.message == message &&
        other.pointer == pointer &&
        other.attribute == attribute &&
        other.relationshipName == relationshipName &&
        other.relationshipAttribute == relationshipAttribute &&
        other.relationshipType == relationshipType &&
        other.relationshipId == relationshipId &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(
    message,
    pointer,
    attribute,
    relationshipName,
    relationshipAttribute,
    relationshipType,
    relationshipId,
    code,
  );
}

class MemberWriteConflictException extends MemberWriteException {
  const MemberWriteConflictException(super.message);
}

class MemberWriteUpdatedAtMissingException extends MemberWriteException {
  const MemberWriteUpdatedAtMissingException(super.message);
}

class MemberWriteAuthRequiredException extends MemberWriteException {
  const MemberWriteAuthRequiredException(super.message);
}

class MemberWriteNetworkBlockedException extends MemberWriteException {
  const MemberWriteNetworkBlockedException(super.message);
}

class MemberWriteRejectedException extends MemberWriteException {
  const MemberWriteRejectedException(super.message);
}

class MemberWriteValidationException extends MemberWriteException {
  const MemberWriteValidationException(
    super.message, {
    this.errors = const <MemberWriteFieldValidationError>[],
  });

  final List<MemberWriteFieldValidationError> errors;
}

abstract class MemberWriteRepository {
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  });

  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  });
}
