// Geraete-Upgrade-Test 0.2.8 -> 1.0.0. Setzt voraus, dass vorher die
// Seed-App aus v0.2.8 auf demselben Geraet lief. Ausfuehren ueber
// tool/upgrade_test/run_upgrade_test.sh, nicht direkt.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nami/main.dart' as app;
import 'package:path_provider/path_provider.dart';

const List<String> _legacyFileNames = <String>[
  'taetigkeit.hive',
  'members.hive',
  'settingsbox.hive',
  'filterbox.hive',
  'datachanges.hive',
  'satzung_db.hive',
  'ai_chat_messages.hive',
  'prod.log',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Update von 0.2.8 verlangt neuen Login und entfernt Altdaten', (
    tester,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    const secureStorage = FlutterSecureStorage();
    final notifications = FlutterLocalNotificationsPlugin();

    // Selbstcheck: Ohne Seed-Spuren wurde die App neu installiert statt
    // aktualisiert, dann waere der Test wertlos.
    final settingsBox = File('${documents.path}/settingsbox.hive');
    expect(
      settingsBox.existsSync(),
      isTrue,
      reason:
          'Keine Daten von 0.2.8 gefunden: App wurde neu installiert statt '
          'aktualisiert, oder der Seed ist nicht gelaufen.',
    );
    expect(
      await secureStorage.read(key: 'key'),
      isNotNull,
      reason:
          'Hive-Schluessel von 0.2.8 nicht lesbar: Keychain/Keystore-Zugriff '
          'unterscheidet sich zwischen den Builds (Signatur/Team pruefen).',
    );
    final legacyNotificationIds =
        (await notifications.pendingNotificationRequests())
            .map((request) => request.id)
            .toSet();
    if (Platform.isAndroid) {
      expect(
        legacyNotificationIds,
        isNotEmpty,
        reason: 'Seed hat keine Geburtstagsbenachrichtigungen geplant.',
      );
    }

    final originalOnError = FlutterError.onError;
    app.main();

    final loginAction = find.byIcon(Icons.login);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (loginAction.evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    FlutterError.onError = originalOnError;

    expect(
      loginAction,
      findsOneWidget,
      reason: 'Nach dem Update muss der Login angeboten werden.',
    );

    for (final fileName in _legacyFileNames) {
      expect(
        File('${documents.path}/$fileName').existsSync(),
        isFalse,
        reason: '$fileName von 0.2.8 wurde nicht entfernt.',
      );
    }
    expect(await secureStorage.read(key: 'key'), isNull);
    expect(await secureStorage.read(key: 'salt'), isNull);

    final remainingIds = (await notifications.pendingNotificationRequests())
        .map((request) => request.id)
        .toSet();
    expect(
      remainingIds.intersection(legacyNotificationIds),
      isEmpty,
      reason: 'Geburtstagsbenachrichtigungen von 0.2.8 sind noch geplant.',
    );
  });
}
