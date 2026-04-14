class HitobitoApiException implements Exception {
  const HitobitoApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
