import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/asset_notifications_data_source.dart';
import 'package:nami/services/logger_service.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.inhalt);

  final String inhalt;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(inhalt)));
}

class _Logger implements LoggerService {
  @override
  Future<void> log(String service, String message) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('liest den Feed aus dem Asset', () async {
    final source = AssetNotificationsDataSource(
      'assets/notifications.json',
      logger: _Logger(),
      bundle: _Bundle(
        '{"items":[{"id":"a","title":"T","body":"B","type":"urgent"}]}',
      ),
    );

    final result = await source.fetch();

    expect(result.single.id, 'a');
    expect(result.single.type, 'urgent');
  });
}
