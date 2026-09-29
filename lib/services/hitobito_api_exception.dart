class HitobitoApiValidationError {
  const HitobitoApiValidationError({
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

  @override
  bool operator ==(Object other) {
    return other is HitobitoApiValidationError &&
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

class HitobitoApiException implements Exception {
  const HitobitoApiException(
    this.message, {
    this.statusCode,
    this.validationErrors = const <HitobitoApiValidationError>[],
  });

  final String message;
  final int? statusCode;
  final List<HitobitoApiValidationError> validationErrors;

  @override
  String toString() => message;
}
