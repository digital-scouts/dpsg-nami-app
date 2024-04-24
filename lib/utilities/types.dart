import 'package:intl/intl.dart';

extension StringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;
}

extension DateTimeExtension on DateTime {
  prettyPrint() {
    return DateFormat('dd.MM.yyyy', 'de_DE').format(this);
  }
}

class SessionExpired implements Exception {}
