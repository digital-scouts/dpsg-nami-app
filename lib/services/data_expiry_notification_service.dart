import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nami/services/logger_service.dart';

import 'benachrichtigungs_berechtigung.dart';

class DataExpiryNotificationService {
  DataExpiryNotificationService({
    required LoggerService logger,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _logger = logger,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _notificationId = 94031;

  final LoggerService _logger;
  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialisierung;

  /// Initialisiert nur das Plugin. Rechte fragt allein
  /// [BenachrichtigungsBerechtigung] an; ohne Erlaubnis zeigt das System die
  /// Erinnerung nicht. Gleichzeitige Aufrufe beim Start teilen sich einen Lauf.
  Future<void> initialize() => _initialisierung ??= _initialisiere();

  Future<void> _initialisiere() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);
  }

  /// Entfernt alle geplanten und angezeigten Benachrichtigungen der App,
  /// ohne dafuer Berechtigungen anzufragen.
  Future<void> cancelAll() {
    return _plugin.cancelAll();
  }

  Future<void> updateExpiryReminder({
    required bool active,
    required int daysRemaining,
  }) async {
    await initialize();

    if (!active) {
      await _plugin.cancel(_notificationId);
      return;
    }

    final normalizedDays = daysRemaining < 1 ? 1 : daysRemaining;

    const androidDetails = AndroidNotificationDetails(
      'data_expiry_reminder',
      'Datenablauf-Erinnerung',
      channelDescription:
          'Erinnert taeglich an eine notwendige erneute Anmeldung.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.periodicallyShow(
      _notificationId,
      'Lokale Daten laufen bald ab',
      'Melde dich innerhalb von $normalizedDays Tagen erneut an, damit lokale Daten verfuegbar bleiben.',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    await _logger.logInfo(
      'notifications',
      'Taegliche Ablauf-Erinnerung aktiviert (days=$normalizedDays)',
    );
  }
}
