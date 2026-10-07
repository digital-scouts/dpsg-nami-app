import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/achievements/achievement_definition.dart';
import '../domain/achievements/achievement_progress.dart';
import '../domain/achievements/achievement_repository.dart';

typedef AchievementNowProvider = DateTime Function();
typedef AchievementPlatformProvider = TargetPlatform Function();

/// Neu erreichte Stufe eines Erfolgs. [tier] ist `null` bei einmaligen
/// Erfolgen.
class AchievementUnlock {
  const AchievementUnlock({required this.definition, this.tier});

  final AchievementDefinition definition;
  final AchievementTier? tier;

  /// Rang für die Auswahl, welche von mehreren Freischaltungen gezeigt wird.
  /// Einmalige Erfolge zählen wie Gold, weil sie ebenfalls gefeiert werden.
  int get rank => tier?.index ?? AchievementTier.gold.index;
}

/// Zählt Tätigkeiten und schaltet lokal gespeicherte Erfolge frei.
///
/// Nicht verfügbare oder auf der aktuellen Plattform nicht vorgesehene Erfolge
/// aus dem Katalog werden ignoriert. Alle Schreib-
/// zugriffe laufen nacheinander, damit parallele Aufrufe (z. B. Start und
/// Resume) sich nicht überschreiben.
class AchievementService {
  AchievementService({
    required AchievementRepository repository,
    AchievementNowProvider? nowProvider,
    AchievementPlatformProvider? platformProvider,
    List<AchievementDefinition> catalog = achievementCatalog,
  }) : _repository = repository,
       _now = nowProvider ?? DateTime.now,
       _platform = platformProvider ?? (() => defaultTargetPlatform),
       _catalog = catalog;

  final AchievementRepository _repository;
  final AchievementNowProvider _now;
  final AchievementPlatformProvider _platform;
  final List<AchievementDefinition> _catalog;
  final StreamController<AchievementUnlock> _unlocks =
      StreamController<AchievementUnlock>.broadcast();
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _queue = Future<void>.value();

  /// Jede neu erreichte Stufe.
  Stream<AchievementUnlock> get unlocks => _unlocks.stream;

  /// Feuert nach jeder gespeicherten Änderung.
  Stream<void> get changes => _changes.stream;

  /// Fortschritt aller verfügbaren Erfolge in Katalogreihenfolge.
  Future<List<AchievementProgress>> loadAll() async {
    await _queue;
    final records = await _repository.load();
    return [
      for (final definition in _catalog.where(
        (d) => d.availableOn(_platform()),
      ))
        AchievementProgress(
          definition: definition,
          count: records[definition.id]?.count ?? 0,
          unlockedAt: records[definition.id]?.unlockedAt ?? const {},
        ),
    ];
  }

  /// Zählt jede Auslösung.
  Future<List<AchievementUnlock>> record(String id) =>
      _enqueue(id, daily: false);

  /// Zählt höchstens einmal pro lokalem Kalendertag.
  Future<List<AchievementUnlock>> recordDaily(String id) =>
      _enqueue(id, daily: true);

  Future<void> dispose() async {
    await _unlocks.close();
    await _changes.close();
  }

  Future<List<AchievementUnlock>> _enqueue(String id, {required bool daily}) {
    final result = _queue.then((_) => _record(id, daily: daily));
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<List<AchievementUnlock>> _record(
    String id, {
    required bool daily,
  }) async {
    final definition = _catalog.where((d) => d.id == id).firstOrNull;
    if (definition == null || !definition.availableOn(_platform())) {
      return const [];
    }

    final now = _now();
    final today = _dayKey(now);
    final records = await _repository.load();
    final current = records[id] ?? const AchievementRecord();
    if (daily && current.lastCountedDay == today) {
      return const [];
    }
    if (definition.isOneTime && current.count >= 1) {
      return const [];
    }

    final before = AchievementProgress(
      definition: definition,
      count: current.count,
    ).reachedLevels;
    final count = current.count + 1;
    final after = AchievementProgress(
      definition: definition,
      count: count,
    ).reachedLevels;

    final unlockedAt = Map<int, DateTime>.of(current.unlockedAt);
    final unlocks = <AchievementUnlock>[];
    for (var level = before; level < after; level++) {
      unlockedAt[level] = now;
      unlocks.add(
        AchievementUnlock(
          definition: definition,
          tier: definition.isOneTime ? null : AchievementTier.values[level],
        ),
      );
    }

    records[id] = current.copyWith(
      count: count,
      unlockedAt: unlockedAt,
      lastCountedDay: daily ? today : null,
    );
    await _repository.save(records);

    _changes.add(null);
    for (final unlock in unlocks) {
      _unlocks.add(unlock);
    }
    return unlocks;
  }

  static String _dayKey(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
