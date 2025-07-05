import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nami/utilities/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  static FlutterLocalNotificationsPlugin get notificationsPlugin =>
      _notificationsPlugin;

  /// Initialisiert den Notification Service
  static Future<void> initialize() async {
    sensLog.i('Initializing notification service');

    // Timezone-Daten initialisieren
    tz.initializeTimeZones();

    const androidInitialize = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosInitialize = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iosInitialize,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Benachrichtigungsberechtigungen anfordern
    await requestNotificationPermissions();

    sensLog.i('Notification service initialized successfully');
  }

  /// Fordert Benachrichtigungsberechtigungen an
  static Future<bool> requestNotificationPermissions() async {
    sensLog.i('Requesting notification permissions');

    try {
      // iOS Berechtigung über flutter_local_notifications
      final bool? iosPermission = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Android Berechtigung über permission_handler
      final androidPermission = await Permission.notification.request();

      sensLog.i(
        'iOS permission: $iosPermission, Android permission: ${androidPermission.isGranted}',
      );

      return iosPermission ?? androidPermission.isGranted;
    } catch (e, st) {
      sensLog.e(
        'Error requesting notification permissions',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Überprüft, ob Benachrichtigungsberechtigungen gewährt wurden
  static Future<bool> areNotificationsEnabled() async {
    try {
      // iOS Check
      final iosPermissions = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();

      final bool iosEnabled = iosPermissions?.isEnabled ?? false;

      // Android Check
      final androidEnabled = await Permission.notification.isGranted;

      return iosEnabled || androidEnabled;
    } catch (e, st) {
      sensLog.e(
        'Error checking notification permissions',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Handler für empfangene Benachrichtigungen
  static void onDidReceiveNotificationResponse(NotificationResponse response) {
    sensLog.i('Notification received: ${response.payload}');
    // Hier können Sie weitere Aktionen implementieren, wenn eine Benachrichtigung angeklickt wird
  }

  /// Zeigt eine einfache Benachrichtigung an
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default Notifications',
        channelDescription: 'Standard Benachrichtigungen der NaMi App',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      sensLog.i('Notification shown: $title');
    } catch (e, st) {
      sensLog.e('Error showing notification', error: e, stackTrace: st);
    }
  }

  /// Zeigt eine geplante Benachrichtigung an
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'scheduled_channel',
        'Scheduled Notifications',
        channelDescription: 'Geplante Benachrichtigungen der NaMi App',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      sensLog.i('Notification scheduled: $title for $scheduledDate');
    } catch (e, st) {
      sensLog.e('Error scheduling notification', error: e, stackTrace: st);
    }
  }

  /// Bricht eine geplante Benachrichtigung ab
  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      sensLog.i('Notification cancelled: $id');
    } catch (e, st) {
      sensLog.e('Error cancelling notification', error: e, stackTrace: st);
    }
  }

  /// Bricht alle Benachrichtigungen ab
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      sensLog.i('All notifications cancelled');
    } catch (e, st) {
      sensLog.e('Error cancelling all notifications', error: e, stackTrace: st);
    }
  }
}
