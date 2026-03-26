import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/services/logger_service.dart';

import 'pull_notification.dart';

class RemoteNotificationsDataSource {
  final String url;
  final LoggerService logger;
  RemoteNotificationsDataSource(this.url, {required this.logger});

  Future<List<PullNotification>> fetch() async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      logger.log(
        'RemoteNotificationsDataSource',
        'Fehler beim Laden der Notifications: ${response.statusCode}',
      );
      throw Exception(
        'Fehler beim Laden der Notifications: ${response.statusCode}',
      );
    }
    final data = json.decode(response.body);
    List items;
    if (data is List) {
      items = data;
    } else if (data is Map && data['items'] is List) {
      items = data['items'];
    } else {
      items = [];
    }
    logger.log(
      'RemoteNotificationsDataSource',
      'Fetched ${items.length} Notifications',
    );
    return items
        .map((e) => PullNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
