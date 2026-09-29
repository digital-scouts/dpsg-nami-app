import '../../domain/achievements/achievement_repository.dart';

class InMemoryAchievementRepository implements AchievementRepository {
  Map<String, AchievementRecord> _records = {};

  @override
  Future<Map<String, AchievementRecord>> load() async => Map.of(_records);

  @override
  Future<void> save(Map<String, AchievementRecord> records) async {
    _records = Map.of(records);
  }
}
