import 'package:hive_ce/hive.dart';

import 'pull_notification.dart';

class LocalNotificationsDataSource {
  static const String _metaBoxName = 'notifications_meta_box';
  static const String _lastFetchAtKey = 'last_fetch_at';

  final Box box;
  LocalNotificationsDataSource(this.box);

  /// Ersetzt den Cache durch die Liste vom Server. Zurueckgezogene
  /// Mitteilungen verschwinden samt ihrer Bestaetigung.
  Future<void> saveNotifications(List<PullNotification> notifications) async {
    final map = {for (var n in notifications) n.id: n.toJson()};
    final veraltet = box.keys.where((key) => !map.containsKey(key)).toList();
    if (veraltet.isNotEmpty) {
      await box.deleteAll(veraltet);
    }
    await box.putAll(map);
    final ackBox = await Hive.openBox('notifications_ack_box');
    final veralteteAcks = ackBox.keys
        .where((key) => !map.containsKey(key))
        .toList();
    if (veralteteAcks.isNotEmpty) {
      await ackBox.deleteAll(veralteteAcks);
    }
  }

  List<PullNotification> getNotifications() {
    return box.values
        .map((e) => PullNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DateTime?> getLastFetchAt() async {
    final metaBox = await Hive.openBox(_metaBoxName);
    final raw = metaBox.get(_lastFetchAtKey);
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  Future<void> setLastFetchAt(DateTime timestamp) async {
    final metaBox = await Hive.openBox(_metaBoxName);
    await metaBox.put(_lastFetchAtKey, timestamp.toIso8601String());
  }

  Future<void> acknowledge(String id) async {
    final ackBox = await Hive.openBox('notifications_ack_box');
    await ackBox.put(id, true);
  }

  Future<void> resetAcknowledgedNotifications() async {
    final ackBox = await Hive.openBox('notifications_ack_box');
    await ackBox.clear();
  }

  Future<Set<String>> getAcknowledgedIds() async {
    final ackBox = await Hive.openBox('notifications_ack_box');
    return ackBox.keys.cast<String>().toSet();
  }
}
