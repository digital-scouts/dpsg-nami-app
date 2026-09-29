/// Stufen eines gestuften Erfolgs in aufsteigender Reihenfolge.
enum AchievementTier { bronze, silver, gold, platinum, diamond }

/// Statische Beschreibung eines Erfolgs.
///
/// Leere [thresholds] bedeuten einen einmaligen Erfolg ohne Stufen.
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    this.thresholds = const [],
    this.available = true,
  });

  final String id;
  final List<int> thresholds;

  /// Nicht verfügbare Erfolge sind vorbereitet, aber noch nicht auslösbar und
  /// werden nicht angezeigt.
  final bool available;

  bool get isOneTime => thresholds.isEmpty;

  int get levelCount => isOneTime ? 1 : thresholds.length;
}

abstract final class AchievementIds {
  static const appDays = 'app_days';
  static const memberEdited = 'member_edited';
  static const statisticsOpened = 'statistics_opened';
  static const memberCreated = 'member_created';
  static const stufenwechselDone = 'stufenwechsel_done';
  static const storeRating = 'store_rating';
  static const feedbackSent = 'feedback_sent';
  static const supporter = 'supporter';
}

const achievementCatalog = <AchievementDefinition>[
  AchievementDefinition(
    id: AchievementIds.appDays,
    thresholds: [3, 10, 25, 100, 500],
  ),
  AchievementDefinition(
    id: AchievementIds.memberEdited,
    thresholds: [1, 5, 20, 50, 200],
  ),
  AchievementDefinition(
    id: AchievementIds.statisticsOpened,
    thresholds: [1, 10, 25, 100, 300],
  ),
  AchievementDefinition(
    id: AchievementIds.memberCreated,
    thresholds: [1, 5, 20, 50, 200],
    available: false,
  ),
  AchievementDefinition(
    id: AchievementIds.stufenwechselDone,
    thresholds: [1, 5, 25, 100, 250],
    available: false,
  ),
  AchievementDefinition(id: AchievementIds.storeRating),
  AchievementDefinition(id: AchievementIds.feedbackSent),
  AchievementDefinition(id: AchievementIds.supporter, available: false),
];
