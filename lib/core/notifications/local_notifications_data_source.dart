import 'package:hive_ce/hive.dart';

import 'pull_notification.dart';

class LocalNotificationsDataSource {
  final Box box;
  LocalNotificationsDataSource(this.box);

  Future<void> saveNotifications(List<PullNotification> notifications) async {
    final map = {for (var n in notifications) n.id: n.toJson()};
    await box.putAll(map);
  }

  List<PullNotification> getNotifications() {
    return box.values
        .map((e) => PullNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
