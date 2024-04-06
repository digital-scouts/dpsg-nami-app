import 'package:flutter/material.dart';
import 'package:nami/main.dart';
import 'package:nami/utilities/logger.dart';

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
    ),
  );
}

void showSnackBar(BuildContext context, String message) {
  fileLog.i('Showing SnackBar');
  consLog.i('Showing SnackBar, message = $message');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
      ),
    ),
  );
}

Future<bool> showConfirmationDialog(
  String title,
  String message,
) async {
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
          }) ??
      false;
}

Future<bool> showWelcomeDialog() async {
  sensLog.i('Showing Welcome Dialog');
  return await showDialog<bool>(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Willkommen!"),
              content: const Text(
                  "Wir freuen uns, dich hier zu haben! \nBitte beachte, dass unsere App sich noch in der Entwicklung befindet und es daher zu Problemen kommen kann. Dein Feedback ist uns jedoch sehr wichtig! Wenn du auf Probleme stößt oder Verbesserungsvorschläge hast, lass es uns bitte wissen. Wir sind dankbar für jede Unterstützung bei der Weiterentwicklung unserer App. \n\nWillkommen an Bord und viel Spaß beim Erkunden!"),
              actions: <Widget>[
                TextButton(
                  child: const Text('Bestätigen'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          }) ??
      false;
}
