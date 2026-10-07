import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/achievements/shared_prefs_achievement_repository.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late SharedPrefsAchievementRepository repository;

  AchievementService buildService() =>
      AchievementService(repository: repository, nowProvider: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 29, 10);
    repository = SharedPrefsAchievementRepository();
  });

  test('record zählt jede Auslösung und schaltet Stufen frei', () async {
    final service = buildService();

    final first = await service.record(AchievementIds.memberEdited);
    expect(first.single.tier, AchievementTier.bronze);

    for (var i = 0; i < 3; i++) {
      expect(await service.record(AchievementIds.memberEdited), isEmpty);
    }
    final fifth = await service.record(AchievementIds.memberEdited);
    expect(fifth.single.tier, AchievementTier.silver);

    final progress = (await service.loadAll()).firstWhere(
      (p) => p.id == AchievementIds.memberEdited,
    );
    expect(progress.count, 5);
    expect(progress.unlockedAt.keys, containsAll(<int>[0, 1]));
  });

  test('recordDaily zählt höchstens einmal pro Kalendertag', () async {
    final service = buildService();

    await service.recordDaily(AchievementIds.appDays);
    await service.recordDaily(AchievementIds.appDays);
    now = DateTime(2026, 9, 29, 23, 59);
    await service.recordDaily(AchievementIds.appDays);

    now = DateTime(2026, 9, 30, 0, 1);
    await service.recordDaily(AchievementIds.appDays);
    now = DateTime(2026, 10, 2);
    final third = await service.recordDaily(AchievementIds.appDays);

    expect(third.single.tier, AchievementTier.bronze);
    final progress = (await service.loadAll()).firstWhere(
      (p) => p.id == AchievementIds.appDays,
    );
    expect(progress.count, 3);
  });

  test('parallele Aufrufe gehen nicht verloren', () async {
    final service = buildService();

    await Future.wait([
      for (var i = 0; i < 6; i++) service.record(AchievementIds.memberEdited),
    ]);

    final progress = (await service.loadAll()).firstWhere(
      (p) => p.id == AchievementIds.memberEdited,
    );
    expect(progress.count, 6);
  });

  test('parallele Tagesaufrufe zählen nur einmal', () async {
    final service = buildService();

    await Future.wait([
      service.recordDaily(AchievementIds.appDays),
      service.recordDaily(AchievementIds.appDays),
    ]);

    final progress = (await service.loadAll()).firstWhere(
      (p) => p.id == AchievementIds.appDays,
    );
    expect(progress.count, 1);
  });

  test('einmalige Erfolge werden genau einmal freigeschaltet', () async {
    final service = AchievementService(
      repository: repository,
      nowProvider: () => now,
      platformProvider: () => TargetPlatform.iOS,
    );

    final first = await service.record(AchievementIds.storeRating);
    final second = await service.record(AchievementIds.storeRating);

    expect(first.single.tier, isNull);
    expect(first.single.definition.id, AchievementIds.storeRating);
    expect(second, isEmpty);
  });

  test('nicht verfügbare Erfolge werden ignoriert und nicht geladen', () async {
    final service = buildService();

    expect(await service.record(AchievementIds.memberCreated), isEmpty);
    expect(await service.record(AchievementIds.supporter), isEmpty);

    final ids = (await service.loadAll()).map((p) => p.id);
    expect(ids, isNot(contains(AchievementIds.memberCreated)));
    expect(ids, isNot(contains(AchievementIds.stufenwechselDone)));
    expect(ids, isNot(contains(AchievementIds.supporter)));
    expect(ids, contains(AchievementIds.appDays));
  });

  test('App bewertet gibt es nur auf iOS', () async {
    AchievementService serviceOn(TargetPlatform platform) => AchievementService(
      repository: repository,
      nowProvider: () => now,
      platformProvider: () => platform,
    );

    final android = serviceOn(TargetPlatform.android);
    expect(await android.record(AchievementIds.storeRating), isEmpty);
    final androidIds = (await android.loadAll()).map((p) => p.id);
    expect(androidIds, isNot(contains(AchievementIds.storeRating)));
    expect(androidIds, contains(AchievementIds.feedbackSent));

    final ios = serviceOn(TargetPlatform.iOS);
    final iosIds = (await ios.loadAll()).map((p) => p.id);
    expect(iosIds, contains(AchievementIds.storeRating));
    expect(
      (await ios.loadAll())
          .firstWhere((p) => p.id == AchievementIds.storeRating)
          .count,
      0,
    );
  });

  test('unlocks und changes melden Freischaltungen', () async {
    final service = buildService();
    final unlocks = <AchievementUnlock>[];
    var changes = 0;
    service.unlocks.listen(unlocks.add);
    service.changes.listen((_) => changes++);

    await service.record(AchievementIds.feedbackSent);
    await service.record(AchievementIds.memberEdited);
    await Future<void>.delayed(Duration.zero);

    expect(unlocks.map((u) => u.definition.id), [
      AchievementIds.feedbackSent,
      AchievementIds.memberEdited,
    ]);
    expect(changes, 2);
    await service.dispose();
  });

  test('Stand bleibt über eine neue Instanz erhalten', () async {
    await buildService().record(AchievementIds.memberEdited);
    await buildService().recordDaily(AchievementIds.statisticsOpened);

    final progress = await buildService().loadAll();
    final edited = progress.firstWhere(
      (p) => p.id == AchievementIds.memberEdited,
    );
    expect(edited.count, 1);
    expect(edited.unlockedAt[0], now);

    // Tagesdeduplizierung überlebt ebenfalls den Neustart.
    expect(
      await buildService().recordDaily(AchievementIds.statisticsOpened),
      isEmpty,
    );
  });

  test('App-Reset per prefs.clear leert den Stand', () async {
    await buildService().record(AchievementIds.memberEdited);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final progress = await buildService().loadAll();
    expect(progress.every((p) => p.count == 0), isTrue);
  });

  test('defekter gespeicherter Stand führt zu leerem Stand', () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsAchievementRepository.stateKey: '{kaputt',
    });

    final progress = await buildService().loadAll();
    expect(progress.every((p) => p.count == 0), isTrue);
  });
}
