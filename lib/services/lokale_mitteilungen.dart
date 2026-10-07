import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_daten;
import 'package:timezone/timezone.dart' as tz;

/// Schmale Schnittstelle zum Benachrichtigungs-Plugin, damit sich geplante
/// Erinnerungen (Qualifikationen, Geburtstage) ohne Plattform testen lassen.
/// Rechte fragt sie nie an; das macht allein `BenachrichtigungsBerechtigung`.
abstract class LokaleMitteilungen {
  Future<void> initialisieren();

  Future<List<int>> geplanteIds();

  Future<void> abbrechen(int id);

  Future<void> planen({
    required int id,
    required String titel,
    required String text,
    required DateTime zeitpunkt,
    required String kanalName,
  });
}

class PluginLokaleMitteilungen implements LokaleMitteilungen {
  /// [kanalId] ist die Android-Kanal-ID; der sichtbare Name kommt beim
  /// Planen lokalisiert mit.
  PluginLokaleMitteilungen({
    required this.kanalId,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final String kanalId;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialisiert = false;

  @override
  Future<void> initialisieren() async {
    if (_initialisiert) {
      return;
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    tz_daten.initializeTimeZones();
    _initialisiert = true;
  }

  @override
  Future<List<int>> geplanteIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((anfrage) => anfrage.id)
          .toList();

  @override
  Future<void> abbrechen(int id) => _plugin.cancel(id);

  @override
  Future<void> planen({
    required int id,
    required String titel,
    required String text,
    required DateTime zeitpunkt,
    required String kanalName,
  }) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        kanalId,
        kanalName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    // Der lokale Zeitpunkt wird als Instant uebergeben; eine lokale Zeitzone
    // braucht das Plugin dafuer nicht.
    return _plugin.zonedSchedule(
      id,
      titel,
      text,
      tz.TZDateTime.from(zeitpunkt, tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
