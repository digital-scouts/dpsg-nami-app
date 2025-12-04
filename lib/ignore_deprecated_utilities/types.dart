import 'package:intl/intl.dart';

extension StringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;
}

extension DateTimeExtension on DateTime {
  String prettyPrint() {
    return DateFormat('dd.MM.yyyy', 'de_DE').format(this);
  }
}

class SessionExpiredException implements Exception {}

class NoGruppierungException implements Exception {}

class NamiServerException implements Exception {}

class MemberCreationException implements Exception {
  final List<FieldInfo> fieldInfo;
  final String message;

  MemberCreationException(this.message, {this.fieldInfo = const []});

  @override
  String toString() {
    return 'MemberCreationException: $message ${fieldInfo.isNotEmpty ? fieldInfo.map((e) => e.toJson()).toList() : ''}';
  }
}

class FieldInfo {
  final String fieldName;
  final String messageId;
  final String level;
  final String message;

  FieldInfo({
    required this.fieldName,
    required this.messageId,
    required this.level,
    required this.message,
  });

  factory FieldInfo.fromJson(Map<String, dynamic> json) {
    return FieldInfo(
      fieldName: json['fieldName'],
      messageId: json['messageId'],
      level: json['level'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldName': fieldName,
      'messageId': messageId,
      'level': level,
      'message': message,
    };
  }
}
