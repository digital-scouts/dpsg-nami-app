import 'package:flutter/material.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';

class NotificationTestWidget extends StatefulWidget {
  final bool initialMessage;

  const NotificationTestWidget({
    super.key,
    this.initialMessage = false,
  });

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  String _statusMessage = 'Benachrichtigungen testen';

  Future<void> _testNotifications() async {
    setState(() {
      _statusMessage = 'Teste Benachrichtigungen...';
    });

    try {
      // Request permissions first
      final permissionGranted =
          await BirthdayNotificationService.requestPermissions();

      if (!permissionGranted) {
        setState(() {
          _statusMessage = 'Benachrichtigungsberechtigungen wurden verweigert';
        });
        return;
      }

      // Send test notification
      final success =
          await BirthdayNotificationService.callTestBenachrichtigung();

      setState(() {
        _statusMessage = success
            ? 'Test-Benachrichtigung erfolgreich gesendet!'
            : 'Fehler beim Senden der Test-Benachrichtigung';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Benachrichtigungstest",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Card(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (widget.initialMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        "Du wirst gleich gebeten Benachrichtigungen zu erlauben. Diese sind notwendig, damit du Geburtstagserinnerungen erhältst.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ElevatedButton.icon(
                    onPressed: _testNotifications,
                    icon: const Icon(Icons.notifications),
                    label: Text(_statusMessage),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Wenn du keine Benachrichtigung erhälst, überprüfe bitte die Einstellungen deines Geräts und stelle sicher, dass die Nami-App Benachrichtigungen senden darf.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
