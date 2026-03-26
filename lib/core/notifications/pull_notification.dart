import 'package:flutter/foundation.dart';

/// Mehrsprachiges Feld für Titel/Body
@immutable
class LocalizedString {
  final String de;
  final String en;

  const LocalizedString({required this.de, required this.en});

  factory LocalizedString.fromJson(dynamic json) {
    if (json is String) {
      // Legacy: Nur einsprachig
      return LocalizedString(de: json, en: json);
    }
    if (json is Map) {
      return LocalizedString(
        de: json['de']?.toString() ?? '',
        en: json['en']?.toString() ?? '',
      );
    }
    // Falls versehentlich ein anderer Typ (z.B. int, List, null)
    final str = json?.toString() ?? '';
    return LocalizedString(de: str, en: str);
  }

  Map<String, dynamic> toJson() => {'de': de, 'en': en};
}

/// Pull Notification Model
@immutable
class PullNotification {
  final String id;
  final LocalizedString title;
  final LocalizedString body;
  final String? type; // info|warn|urgent
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? deepLink;
  final String? externalLink;
  final String platform; // android|ios|all

  const PullNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.createdAt,
    this.updatedAt,
    this.startsAt,
    this.endsAt,
    this.deepLink,
    this.externalLink,
    String? platform,
  }) : platform = platform ?? 'all';

  factory PullNotification.fromJson(Map<String, dynamic> json) {
    return PullNotification(
      id: json['id'] as String,
      title: LocalizedString.fromJson(json['title']),
      body: LocalizedString.fromJson(json['body']),
      type: json['type'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'])
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'])
          : null,
      deepLink: json['deep_link'] as String?,
      externalLink: json['external_link'] as String?,
      platform: (json['platform'] as String?) ?? 'all',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title.toJson(),
    'body': body.toJson(),
    if (type != null) 'type': type,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (startsAt != null) 'starts_at': startsAt!.toIso8601String(),
    if (endsAt != null) 'ends_at': endsAt!.toIso8601String(),
    if (deepLink != null) 'deep_link': deepLink,
    if (externalLink != null) 'external_link': externalLink,
    'platform': platform,
  };
}
