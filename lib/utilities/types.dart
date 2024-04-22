extension StringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;
}

extension DateTimeExtension on DateTime {
  prettyPrint() {
    return "${day < 10 ? '0' : ''}$day.${month < 10 ? '0' : ''}$month.$year";
  }
}

class SessionExpired implements Exception {}
