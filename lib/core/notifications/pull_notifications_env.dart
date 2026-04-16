import 'package:flutter_dotenv/flutter_dotenv.dart';

class PullNotificationsEnv {
  static String get url => dotenv.env['PULL_NOTIFICATIONS_URL'] ?? '';

  static Duration get minFetchInterval {
    final hoursRaw = dotenv.env['PULL_NOTIFICATIONS_MIN_FETCH_INTERVAL_HOURS'];
    final hours = int.tryParse(hoursRaw ?? '');
    if (hours == null || hours < 0) {
      return const Duration(hours: 1);
    }
    return Duration(hours: hours);
  }
}
