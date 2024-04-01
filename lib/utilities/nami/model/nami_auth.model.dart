class NamiAuthModel {
  final int statusCode;
  final String statusMessage;
  final String apiSessionName;
  final String apiSessionToken;
  final int minorNumber;
  final int majorNumber;

  NamiAuthModel({
    required this.statusCode,
    required this.statusMessage,
    required this.apiSessionName,
    required this.apiSessionToken,
    required this.minorNumber,
    required this.majorNumber,
  });

  factory NamiAuthModel.fromJson(Map<String, dynamic> json) {
    return NamiAuthModel(
      statusCode: json['statusCode'],
      statusMessage: json['statusMessage'],
      apiSessionName: json['apiSessionName'],
      apiSessionToken: json['apiSessionToken'],
      minorNumber: json['minorNumber'],
      majorNumber: json['majorNumber'],
    );
  }
}
