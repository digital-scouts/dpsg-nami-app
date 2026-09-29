/// Gespeicherter Stand eines einzelnen Erfolgs.
class AchievementRecord {
  const AchievementRecord({
    this.count = 0,
    this.unlockedAt = const {},
    this.lastCountedDay,
  });

  final int count;

  /// Freischaltzeitpunkt je Stufenindex.
  final Map<int, DateTime> unlockedAt;

  /// Lokaler Kalendertag (`yyyy-MM-dd`) der letzten Tageszählung.
  final String? lastCountedDay;

  AchievementRecord copyWith({
    int? count,
    Map<int, DateTime>? unlockedAt,
    String? lastCountedDay,
  }) {
    return AchievementRecord(
      count: count ?? this.count,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      lastCountedDay: lastCountedDay ?? this.lastCountedDay,
    );
  }
}

/// Lokale Ablage der Erfolge. Es gibt bewusst keinen Server-Sync.
abstract class AchievementRepository {
  Future<Map<String, AchievementRecord>> load();

  Future<void> save(Map<String, AchievementRecord> records);
}
