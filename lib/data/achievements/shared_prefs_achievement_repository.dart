import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/achievements/achievement_repository.dart';

class SharedPrefsAchievementRepository implements AchievementRepository {
  SharedPrefsAchievementRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _prefs = preferencesProvider ?? SharedPreferences.getInstance;

  static const String stateKey = 'achievements.v1.state';

  final Future<SharedPreferences> Function() _prefs;

  @override
  Future<Map<String, AchievementRecord>> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(stateKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: _decodeRecord(entry.value as Map<String, dynamic>),
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, AchievementRecord> records) async {
    final prefs = await _prefs();
    await prefs.setString(
      stateKey,
      jsonEncode({
        for (final entry in records.entries)
          entry.key: _encodeRecord(entry.value),
      }),
    );
  }

  static Map<String, Object?> _encodeRecord(AchievementRecord record) => {
    'count': record.count,
    'unlocked_at': {
      for (final entry in record.unlockedAt.entries)
        '${entry.key}': entry.value.toIso8601String(),
    },
    'last_counted_day': ?record.lastCountedDay,
  };

  static AchievementRecord _decodeRecord(Map<String, dynamic> json) {
    final unlocked = json['unlocked_at'];
    return AchievementRecord(
      count: json['count'] is int ? json['count'] as int : 0,
      unlockedAt: {
        if (unlocked is Map<String, dynamic>)
          for (final entry in unlocked.entries)
            if (int.tryParse(entry.key) != null &&
                entry.value is String &&
                DateTime.tryParse(entry.value as String) != null)
              int.parse(entry.key): DateTime.parse(entry.value as String),
      },
      lastCountedDay: json['last_counted_day'] as String?,
    );
  }
}
