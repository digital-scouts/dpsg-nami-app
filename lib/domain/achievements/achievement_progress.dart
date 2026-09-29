import 'package:equatable/equatable.dart';

import 'achievement_definition.dart';

/// Fortschritt eines Nutzers für einen Erfolg.
class AchievementProgress extends Equatable {
  const AchievementProgress({
    required this.definition,
    this.count = 0,
    this.unlockedAt = const {},
  });

  final AchievementDefinition definition;
  final int count;

  /// Freischaltzeitpunkt je erreichter Stufe (Index 0 = erste Stufe bzw.
  /// einmaliger Erfolg).
  final Map<int, DateTime> unlockedAt;

  String get id => definition.id;

  int get reachedLevels {
    if (definition.isOneTime) {
      return count >= 1 ? 1 : 0;
    }
    return definition.thresholds.where((t) => count >= t).length;
  }

  bool get isUnlocked => reachedLevels > 0;

  bool get isComplete => reachedLevels == definition.levelCount;

  AchievementTier? get currentTier => definition.isOneTime || !isUnlocked
      ? null
      : AchievementTier.values[reachedLevels - 1];

  AchievementTier? get nextTier => definition.isOneTime || isComplete
      ? null
      : AchievementTier.values[reachedLevels];

  int? get nextThreshold => isComplete
      ? null
      : definition.isOneTime
      ? 1
      : definition.thresholds[reachedLevels];

  /// Anteil 0..1 bis zur nächsten Stufe, gemessen ab 0.
  double get progressToNext {
    final next = nextThreshold;
    if (next == null) {
      return 1;
    }
    return (count / next).clamp(0, 1).toDouble();
  }

  DateTime? get lastUnlockedAt {
    if (unlockedAt.isEmpty) {
      return null;
    }
    return unlockedAt.values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  @override
  List<Object?> get props => [definition.id, count, unlockedAt];
}
