import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<void> showWelcomeDialog(BuildContext context) async {
  final t = AppLocalizations.of(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(t.t('welcome_title')),
        content: Text(t.t('welcome_body')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.t('welcome_action')),
          ),
        ],
      );
    },
  );
}
