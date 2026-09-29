// Seed-Entrypoint fuer den Geraete-Upgrade-Test. Wird in einen Worktree von
// v0.2.8 nach lib/main_seed_0_2_8.dart kopiert und als eigene App gebaut,
// siehe tool/upgrade_test/run_upgrade_test.sh.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';
import 'package:path_provider/path_provider.dart';

import 'legacy_seed.dart';

const String seedDoneMarker = 'NAMI_LEGACY_SEED_DONE';
const String seedFailedMarker = 'NAMI_LEGACY_SEED_FAILED';

/// Wird vom Runner-Skript gelesen und danach wieder entfernt.
const String seedStatusFileName = 'legacy_seed_status.txt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String status;
  try {
    status = '$seedDoneMarker ${await _seed()}';
  } catch (error, stackTrace) {
    status = '$seedFailedMarker $error\n$stackTrace';
  }
  // ignore: avoid_print
  print(status);
  final documents = await getApplicationDocumentsDirectory();
  await File('${documents.path}/$seedStatusFileName').writeAsString(status);
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(status))),
    ),
  );
}

Future<String> _seed() async {
  // Wie main() in 0.2.8.
  await Hive.initFlutter();
  final members = await seedLegacyData();

  // Wie initLogger() in 0.2.8.
  const secureStorage = FlutterSecureStorage();
  await secureStorage.write(
    key: 'salt',
    value: Random.secure().nextInt(1 << 32).toString(),
  );
  final documents = await getApplicationDocumentsDirectory();
  await File('${documents.path}/prod.log').writeAsString(
    '<log time="${DateTime.now().toIso8601String()}" level="info">Seed</log>\n',
  );

  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();

  await BirthdayNotificationService.init();
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
  String notificationStatus;
  try {
    for (final member in members) {
      await BirthdayNotificationService.scheduleBirthdayNotification(member);
    }
    final pending =
        await BirthdayNotificationService.getAllPlannedNotifications();
    notificationStatus = '${pending.length}';
  } catch (error) {
    // Im iOS-Simulator laesst sich die Berechtigung nicht automatisiert
    // erteilen; 0.2.8 plant dann ebenfalls nichts. Android deckt das ab.
    if (Platform.isAndroid) {
      rethrow;
    }
    notificationStatus = 'skipped ($error)';
  }

  await Hive.close();
  return 'members=${members.length} notifications=$notificationStatus';
}
