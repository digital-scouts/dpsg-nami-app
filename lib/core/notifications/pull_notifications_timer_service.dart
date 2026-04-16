import 'dart:async';

class PullNotificationsTimerService {
  final Duration interval;
  Timer? _timer;
  void Function()? onTick;

  PullNotificationsTimerService({required this.interval, this.onTick});

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick?.call());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
