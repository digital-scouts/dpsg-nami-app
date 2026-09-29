import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notifications_timer_service.dart';

void main() {
  test('start loest periodische Ticks aus', () async {
    var ticks = 0;
    final service = PullNotificationsTimerService(
      interval: const Duration(milliseconds: 10),
      onTick: () => ticks++,
    );

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 35));
    service.stop();

    expect(ticks, greaterThanOrEqualTo(2));
  });

  test('stop beendet weitere Ticks', () async {
    var ticks = 0;
    final service = PullNotificationsTimerService(
      interval: const Duration(milliseconds: 10),
      onTick: () => ticks++,
    );

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    service.stop();
    final ticksAfterStop = ticks;
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(ticks, ticksAfterStop);
  });
}
