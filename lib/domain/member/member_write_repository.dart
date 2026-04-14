import 'mitglied.dart';

class MemberWriteException implements Exception {
  const MemberWriteException(this.message);

  final String message;

  @override
  String toString() => message;
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

class MemberWriteRejectedException extends MemberWriteException {
  const MemberWriteRejectedException(super.message);
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
