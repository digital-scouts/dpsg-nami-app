import 'package:flutter_dotenv/flutter_dotenv.dart';

class PullNotificationsEnv {
  static String get url => dotenv.env['PULL_NOTIFICATIONS_URL'] ?? '';
}
