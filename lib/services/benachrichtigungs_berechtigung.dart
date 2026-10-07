import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Einzige Stelle, die das System nach Benachrichtigungsrechten fragt: im
/// Willkommen-Stepper und beim Einschalten in den Einstellungen, nie
/// ungefragt beim Start. Gleichzeitige Aufrufe teilen sich eine Anfrage,
/// damit iOS den Systemdialog nicht doppelt zeigt.
class BenachrichtigungsBerechtigung {
  BenachrichtigungsBerechtigung({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _laufendeAnfrage;

  /// Zeigt den Systemdialog (falls noch nicht entschieden) und liefert, ob
  /// Benachrichtigungen erlaubt sind.
  Future<bool> anfragen() => _laufendeAnfrage ??= _anfragen().whenComplete(() {
    _laufendeAnfrage = null;
  });

  Future<bool> _anfragen() async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return android ?? ios ?? false;
  }

  /// Aktueller Stand ohne Systemdialog; `null`, wenn unbekannt. Achtung:
  /// iOS und Android melden `false` auch, solange noch nie gefragt wurde.
  Future<bool?> istErlaubt() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return android.areNotificationsEnabled();
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return (await ios?.checkPermissions())?.isEnabled;
  }
}
