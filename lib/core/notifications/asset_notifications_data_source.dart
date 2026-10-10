import 'dart:convert';

import 'package:flutter/services.dart';

import 'pull_notification.dart';
import 'remote_notifications_data_source.dart';

/// Entwicklungsquelle: liest den Mitteilungs-Feed aus einem Asset statt von
/// der URL, damit sich Meldungen ohne Commit auf `master` testen lassen.
class AssetNotificationsDataSource extends RemoteNotificationsDataSource {
  AssetNotificationsDataSource(
    this.assetPath, {
    required super.logger,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle,
       super('');

  final String assetPath;
  final AssetBundle _bundle;

  @override
  Future<List<PullNotification>> fetch() async {
    final raw = await _bundle.loadString(assetPath, cache: false);
    final items = RemoteNotificationsDataSource.parseFeed(json.decode(raw));
    await logger.log(
      'AssetNotificationsDataSource',
      'Asset $assetPath: ${items.length} Notifications',
    );
    return items;
  }
}
