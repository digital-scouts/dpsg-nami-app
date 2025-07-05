import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class BirthdayNotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );
    await _notifications.initialize(settings);
  }

  static Future<List<PendingNotificationRequest>>
      getAllPlannedNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> cancelAllBirthdayNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<bool> callTestBenachrichtigung(
      {duration = const Duration(seconds: 5)}) async {
    try {
      await _notifications.show(
        0, // unique id
        'Test Benachrichtigung',
        'Dies ist eine Testbenachrichtigung für Geburtstage.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'birthday_channel',
            'Geburtstage',
            channelDescription: 'Erinnerungen an Geburtstage',
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> scheduleAllBirthdays() async {
    await cancelAllBirthdayNotifications();

    List<Stufe> stufen = getGeburtstagsbenachrichtigungenGruppen();

    List<Mitglied> mitglieder = Hive.box<Mitglied>('members')
        .values
        .where((element) => stufen.contains(element.currentStufe))
        .toList()
        .cast<Mitglied>();

    // Sortiere nach dem nächsten Geburtstag (aufsteigend)
    mitglieder.sort((a, b) {
      DateTime now = DateTime.now();
      DateTime nextA =
          DateTime(now.year, a.geburtsDatum.month, a.geburtsDatum.day);
      if (nextA.isBefore(now)) {
        nextA =
            DateTime(now.year + 1, a.geburtsDatum.month, a.geburtsDatum.day);
      }
      DateTime nextB =
          DateTime(now.year, b.geburtsDatum.month, b.geburtsDatum.day);
      if (nextB.isBefore(now)) {
        nextB =
            DateTime(now.year + 1, b.geburtsDatum.month, b.geburtsDatum.day);
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
    DateTime nextBirthday = DateTime(
      now.year,
      mitglied.geburtsDatum.month,
      mitglied.geburtsDatum.day,
    );
    if (nextBirthday.isBefore(now)) {
      nextBirthday = DateTime(
        now.year + 1,
        mitglied.geburtsDatum.month,
        mitglied.geburtsDatum.day,
      );
    }

    await _notifications.zonedSchedule(
        mitglied.id.hashCode, // unique id
        'Geburtstag',
        '${mitglied.vorname} ${mitglied.nachname} hat heute Geburtstag!',
        tz.TZDateTime.from(nextBirthday, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'birthday_channel',
            'Geburtstage',
            channelDescription: 'Erinnerungen an Geburtstage',
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload:
            '${nextBirthday.day}.${nextBirthday.month}.${nextBirthday.year}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
  }
}
