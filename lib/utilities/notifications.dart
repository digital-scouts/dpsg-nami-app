import 'package:flutter/material.dart';
import 'package:nami/main.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/logger.dart';

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
    ),
  );
}

void showSnackBar(BuildContext context, String message) {
  fileLog.i('Showing SnackBar');
  consLog.i('Showing SnackBar, message = $message');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: Duration(seconds: 10)),
  );
}

Future<bool> showConfirmationDialog(String title, String message) async {
  sensLog.i('Showing Confirmation Dialog, title = $title');
  return await showDialog<bool>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: const Text('Abbrechen'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Bestätigen'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      ) ??
      false;
}

Future<bool> showSendLogsDialog() async {
  sensLog.i('Showing share logs dialog');

  return await showDialog<bool>(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("App Logs teilen"),
            content: const Text(
              "Du hast die Möglichkeit automatisch generierte Logs der Aktivitäten mit den Entwicklern zu teilen, um bei der Fehlerbehebung zu helfen. Dabei werden folgende Daten gesammelt: gekürzte Mitgliedsnummer und ID, eigene Rechte, Mitglieder und Tätigkeiten ohne Personenbezogene Daten.",
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Abbrechen'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Bestätigen'),
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await sendLogsEmail();
                },
              ),
            ],
          );
        },
      ) ??
      false;
}
