import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';

void main() {
  const tiered = AchievementDefinition(
    id: 'test',
    thresholds: [3, 10, 25, 100, 500],
  );
  const oneTime = AchievementDefinition(id: 'once');

  group('AchievementProgress gestuft', () {
    test('ohne Fortschritt ist nichts erreicht', () {
      const p = AchievementProgress(definition: tiered);
      expect(p.reachedLevels, 0);
      expect(p.isUnlocked, isFalse);
      expect(p.currentTier, isNull);
      expect(p.nextTier, AchievementTier.bronze);
      expect(p.nextThreshold, 3);
      expect(p.progressToNext, 0);
    });

    test('genau auf der Schwelle gilt die Stufe als erreicht', () {
      const p = AchievementProgress(definition: tiered, count: 10);
      expect(p.currentTier, AchievementTier.silver);
      expect(p.nextTier, AchievementTier.gold);
      expect(p.nextThreshold, 25);
      expect(p.progressToNext, closeTo(0.4, 1e-9));
    });

    test('knapp unter der Schwelle bleibt die vorherige Stufe', () {
      const p = AchievementProgress(definition: tiered, count: 24);
      expect(p.currentTier, AchievementTier.silver);
    });

    test('ab der letzten Schwelle ist der Erfolg vollständig', () {
      const p = AchievementProgress(definition: tiered, count: 800);
      expect(p.currentTier, AchievementTier.diamond);
      expect(p.isComplete, isTrue);
      expect(p.nextTier, isNull);
      expect(p.nextThreshold, isNull);
      expect(p.progressToNext, 1);
    });
  });

  group('AchievementProgress einmalig', () {
    test('ist ohne Zählung gesperrt', () {
      const p = AchievementProgress(definition: oneTime);
      expect(p.isUnlocked, isFalse);
      expect(p.nextThreshold, 1);
      expect(p.currentTier, isNull);
    });

    test('ist nach einer Auslösung vollständig und hat keine Stufe', () {
      const p = AchievementProgress(definition: oneTime, count: 1);
      expect(p.isUnlocked, isTrue);
      expect(p.isComplete, isTrue);
      expect(p.currentTier, isNull);
      expect(p.nextTier, isNull);
    });
  });

  test('lastUnlockedAt liefert den jüngsten Zeitpunkt', () {
    final p = AchievementProgress(
      definition: tiered,
      count: 12,
      unlockedAt: {0: DateTime(2026, 9, 1), 1: DateTime(2026, 9, 20)},
    );
    expect(p.lastUnlockedAt, DateTime(2026, 9, 20));
  });

  test('Katalog: gestufte Erfolge haben fünf aufsteigende Schwellen', () {
    for (final d in achievementCatalog.where((d) => !d.isOneTime)) {
      expect(d.thresholds, hasLength(AchievementTier.values.length));
      for (var i = 1; i < d.thresholds.length; i++) {
        expect(d.thresholds[i], greaterThan(d.thresholds[i - 1]), reason: d.id);
      }
    }
  });
}
