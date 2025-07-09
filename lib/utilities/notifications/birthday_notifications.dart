import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/main.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wiredash/wiredash.dart';

class BirthdayNotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final NotificationDetails _defaultNotificationDetails =
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday_channel',
          'Geburtstage',
          channelDescription: 'Erinnerungen an Geburtstage',
          icon: '@drawable/ic_notification',
          color: Color.fromARGB(255, 255, 251, 0), // Grün
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false, // Keine automatische Berechtigung
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Fordert explizit Benachrichtigungsberechtigungen an
  static Future<bool> requestPermissions() async {
    final IOSFlutterLocalNotificationsPlugin? iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (iosImplementation != null) {
      final bool? granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      scheduleAllBirthdays();
      return granted ?? false;
    }

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation
          .requestNotificationsPermission();
      scheduleAllBirthdays();
      return granted ?? false;
    }
    scheduleAllBirthdays();
    return true; // Fallback für andere Plattformen
  }

  static Future<List<PendingNotificationRequest>>
  getAllPlannedNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> cancelAllBirthdayNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<bool> callTestBenachrichtigung() async {
    try {
      await _notifications.zonedSchedule(
        9999,
        'Test Benachrichtigung',
        'Dies ist eine Testbenachrichtigung für Geburtstage.',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        _defaultNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> scheduleAllBirthdays() async {
    await cancelAllBirthdayNotifications();

    List<Stufe> stufen = getGeburtstagsbenachrichtigungenGruppen();

    List<Mitglied> mitglieder = Hive.box<Mitglied>('members').values
        .where((element) => stufen.contains(element.currentStufe))
        .toList()
        .cast<Mitglied>();

    // Sortiere nach dem nächsten Geburtstag (aufsteigend)
    mitglieder.sort((a, b) {
      DateTime now = DateTime.now();
      DateTime nextA = DateTime(
        now.year,
        a.geburtsDatum.month,
        a.geburtsDatum.day,
      );
      if (nextA.isBefore(now)) {
        nextA = DateTime(
          now.year + 1,
          a.geburtsDatum.month,
          a.geburtsDatum.day,
        );
      }
      DateTime nextB = DateTime(
        now.year,
        b.geburtsDatum.month,
        b.geburtsDatum.day,
      );
      if (nextB.isBefore(now)) {
        nextB = DateTime(
          now.year + 1,
          b.geburtsDatum.month,
          b.geburtsDatum.day,
        );
      }
      return nextA.compareTo(nextB);
    });

    // Nur die nächsten 25 Geburtstage einplanen
    for (final mitglied in mitglieder.take(25)) {
      await scheduleBirthdayNotification(mitglied);
    }
  }

  static Future<void> scheduleBirthdayNotification(Mitglied mitglied) async {
    final now = DateTime.now();
    BenachrichtigungsZeit zeitpunkt = getBenachrichtigungsZeitpunkt();

    DateTime notificationDate = DateTime(
      now.year,
      mitglied.geburtsDatum.month,
      mitglied.geburtsDatum.day + zeitpunkt.tageOffset,
      zeitpunkt.stunde,
    );

    // Falls der Geburtstag bereits vorbei ist, nächstes Jahr
    if (notificationDate.isBefore(now)) {
      notificationDate = DateTime(
        now.year + 1,
        mitglied.geburtsDatum.month,
        mitglied.geburtsDatum.day + zeitpunkt.tageOffset,
        zeitpunkt.stunde,
      );
    }

    await _notifications.zonedSchedule(
      mitglied.id.hashCode,
      'Geburtstag',
      '${mitglied.vorname} ${mitglied.nachname} hat ${zeitpunkt.tageOffset == 0 ? 'heute' : 'morgen'} Geburtstag!',
      tz.TZDateTime.from(notificationDate, tz.local),
      _defaultNotificationDetails,
      payload:
          '${mitglied.id.toString()}-${notificationDate.day}.${notificationDate.month}.${notificationDate.year} ${notificationDate.hour} Uhr',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.dateAndTime, // Jährliche Wiederholung
    );
  }

  /// Wird aufgerufen, wenn auf eine Benachrichtigung geklickt wird
  static Future<void> _onNotificationTapped(
    NotificationResponse response,
  ) async {
    Wiredash.trackEvent(
      'Geburtstagsbenachrichtigung',
      data: {'type': 'Details durch Benachrichtigung geöffnet'},
    );
    final payload = response.payload;

    if (payload == null || payload.isEmpty) return;

    // Payload-Format: "mitgliedId"
    try {
      final int mitgliedId = int.parse(payload.split('-').first);

      // Mitglied aus Hive laden
      final mitglied = Hive.box<Mitglied>(
        'members',
      ).values.where((m) => m.id == mitgliedId).firstOrNull;

      if (mitglied != null) {
        // Zur MitgliedDetail-Seite navigieren
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MitgliedDetail(mitglied: mitglied),
          ),
        );
      }
    } catch (e) {
      // Fehler beim Parsen der Payload ignorieren
      sensLog.e('Fehler beim Öffnen der Mitgliedsdetails: $e');
    }
  }
}
