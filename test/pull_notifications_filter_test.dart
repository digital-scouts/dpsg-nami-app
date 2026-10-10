import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_filter.dart';

void main() {
  final now = DateTime.utc(2026, 6, 4, 12);

  PullNotification meldung(
    String id, {
    String? platform,
    DateTime? startsAt,
    DateTime? endsAt,
  }) => PullNotification(
    id: id,
    title: const LocalizedString(de: 'T', en: 'T'),
    body: const LocalizedString(de: 'B', en: 'B'),
    platform: platform,
    startsAt: startsAt,
    endsAt: endsAt,
  );

  List<String> ids(List<PullNotification> list, {String platform = 'ios'}) =>
      filterAktiveMeldungen(
        list,
        now: now,
        platform: platform,
      ).map((n) => n.id).toList();

  test('filtert nach Plattform, all und leer gelten ueberall', () {
    final list = [
      meldung('alle'),
      meldung('ios', platform: 'iOS'),
      meldung('android', platform: 'android'),
      meldung('leer', platform: ' '),
    ];

    expect(ids(list), ['alle', 'ios', 'leer']);
    expect(ids(list, platform: 'android'), ['alle', 'android', 'leer']);
  });

  test('beachtet starts_at und ends_at an den Grenzen', () {
    final list = [
      meldung('startet-jetzt', startsAt: now),
      meldung('startet-spaeter', startsAt: now.add(const Duration(minutes: 1))),
      meldung('endet-jetzt', endsAt: now),
      meldung('endet-spaeter', endsAt: now.add(const Duration(minutes: 1))),
    ];

    expect(ids(list), ['startet-jetzt', 'endet-spaeter']);
  });
}
