import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/services/logger_service.dart';

import 'pull_notification.dart';

class RemoteNotificationsDataSource {
  final String url;
  final LoggerService logger;
  RemoteNotificationsDataSource(this.url, {required this.logger});

  Future<List<PullNotification>> fetch() async {
    final uri = Uri.parse(url);
    http.Response response;
    try {
      response = await http.get(uri);
    } catch (error) {
      await logger.logHttpRequest(
        source: 'remote_notifications',
        method: 'GET',
        uri: uri,
        error: error,
      );
      rethrow;
    }
    await logger.logHttpRequest(
      source: 'remote_notifications',
      method: 'GET',
      uri: uri,
      statusCode: response.statusCode,
    );
    if (response.statusCode != 200) {
      await logger.log(
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
    await logger.log(
      'RemoteNotificationsDataSource',
      'Fetched ${items.length} Notifications',
    );
    return items
        .map((e) => PullNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
