import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/shared_prefs_app_settings_repository.dart';
import 'package:nami/services/benachrichtigungs_berechtigung.dart';
import 'package:nami/services/data_expiry_notification_service.dart';
import 'package:nami/services/logger_service.dart';

/// Ersetzt die iOS-Implementierung des Plugins ohne Plattformkanal.
class _FakeIos extends IOSFlutterLocalNotificationsPlugin {
  int anfragen = 0;
  final initialisierungen = <DarwinInitializationSettings>[];
  Completer<bool> antwort = Completer<bool>();

  @override
  Future<bool?> initialize(
    DarwinInitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialisierungen.add(initializationSettings);
    return true;
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) {
    anfragen++;
    return antwort.future;
  }
}

// Bei active: false schreibt der Dienst nichts ins Log.
LoggerService _logger() => LoggerService(
  settingsRepository: SharedPrefsAppSettingsRepository(),
  navigatorKey: GlobalKey<NavigatorState>(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeIos ios;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ios = _FakeIos();
    FlutterLocalNotificationsPlatform.instance = ios;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('der Start fragt keine Rechte an, auch bei doppeltem Aufruf', () async {
    final service = DataExpiryNotificationService(logger: _logger());

    await Future.wait([
      service.updateExpiryReminder(active: false, daysRemaining: 0),
      service.updateExpiryReminder(active: false, daysRemaining: 0),
    ]);

    expect(ios.anfragen, 0);
    expect(ios.initialisierungen, hasLength(1));
    final settings = ios.initialisierungen.single;
    expect(settings.requestAlertPermission, isFalse);
    expect(settings.requestBadgePermission, isFalse);
    expect(settings.requestSoundPermission, isFalse);
  });

  test('gleichzeitige Anfragen zeigen den Systemdialog nur einmal', () async {
    final berechtigung = BenachrichtigungsBerechtigung();

    final erste = berechtigung.anfragen();
    final zweite = berechtigung.anfragen();
    ios.antwort.complete(true);

    expect(await erste, isTrue);
    expect(await zweite, isTrue);
    expect(ios.anfragen, 1);
  });

  test('eine spätere Anfrage fragt erneut', () async {
    final berechtigung = BenachrichtigungsBerechtigung();

    final erste = berechtigung.anfragen();
    ios.antwort.complete(false);
    expect(await erste, isFalse);

    ios.antwort = Completer<bool>()..complete(true);
    expect(await berechtigung.anfragen(), isTrue);
    expect(ios.anfragen, 2);
  });
}
