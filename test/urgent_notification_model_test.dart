import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/presentation/model/urgent_notification_model.dart';

PullNotification _meldung(String id) => PullNotification(
  id: id,
  title: const LocalizedString(de: 'T', en: 'T'),
  body: const LocalizedString(de: 'B', en: 'B'),
  type: 'urgent',
);

void main() {
  test('zeigt die erste Meldung und zaehlt alle offenen', () {
    final model = UrgentNotificationModel();

    model.setNotifications([_meldung('a'), _meldung('b'), _meldung('c')]);

    expect(model.notification?.id, 'a');
    expect(model.count, 3);
  });

  test('nach dem Bestaetigen rueckt die naechste nach', () async {
    final model = UrgentNotificationModel();
    final offen = [_meldung('a'), _meldung('b')];
    model.setAcknowledgeHandler((id) async {
      offen.removeWhere((n) => n.id == id);
      model.setNotifications(List.of(offen));
    });
    model.setNotifications(List.of(offen));

    await model.acknowledgeCurrent();

    expect(model.notification?.id, 'b');
    expect(model.count, 1);
  });

  test('benachrichtigt nur bei geaenderter Reihenfolge', () {
    final model = UrgentNotificationModel();
    var aufrufe = 0;
    model.addListener(() => aufrufe++);

    model.setNotifications([_meldung('a')]);
    model.setNotifications([_meldung('a')]);
    model.setNotifications(const []);

    expect(aufrufe, 2);
    expect(model.notification, isNull);
  });
}
