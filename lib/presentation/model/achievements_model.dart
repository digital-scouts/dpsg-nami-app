import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/achievements/achievement_progress.dart';
import '../../services/achievement_service.dart';

/// Stellt den Fortschritt aller verfügbaren Erfolge für die UI bereit und
/// lädt nach jeder Änderung im [AchievementService] neu.
class AchievementsModel extends ChangeNotifier {
  AchievementsModel({required AchievementService service})
    : _service = service {
    _subscription = _service.changes.listen((_) => unawaited(load()));
  }

  final AchievementService _service;
  late final StreamSubscription<void> _subscription;
  List<AchievementProgress> _achievements = const [];
  bool _disposed = false;

  List<AchievementProgress> get achievements => _achievements;

  Future<void> load() async {
    final loaded = await _service.loadAll();
    if (_disposed) {
      return;
    }
    _achievements = loaded;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
