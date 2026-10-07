import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/services/logger_service.dart';

import 'pull_notification.dart';

class RemoteNotificationsDataSource {
  final String url;
  final LoggerService logger;
  final http.Client? _client;
  final Duration _timeout;

  RemoteNotificationsDataSource(
    this.url, {
    required this.logger,
    http.Client? client,
    Duration timeout = const Duration(seconds: 5),
  }) : _client = client,
       _timeout = timeout;

  /// Nur https; http bleibt fuer lokale Tests auf Loopback erlaubt (A-50).
  static bool istErlaubt(Uri uri) =>
      uri.scheme == 'https' && uri.host.isNotEmpty ||
      uri.scheme == 'http' &&
          (uri.host == 'localhost' || uri.host == '127.0.0.1');

  Future<List<PullNotification>> fetch() async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !istErlaubt(uri)) {
      throw StateError('Mitteilungs-URL fehlt oder ist nicht https');
    }
    http.Response response;
    try {
      final client = _client;
      response = await (client == null ? http.get(uri) : client.get(uri))
          .timeout(_timeout);
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
