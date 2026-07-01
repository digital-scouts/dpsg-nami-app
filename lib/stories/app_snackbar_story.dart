import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story appSnackbarStory() => Story(
  name: 'App/Feedback/Snackbar',
  builder: (context) {
    final longMessage = context.knobs.boolean(
      label: 'Lange Nachricht',
      initial: false,
    );
    final message = longMessage
        ? 'Dies ist eine bewusst längere Snackbar-Nachricht, damit Umbüche, maximale Zeilenanzahl und die Lesbarkeit in der App-Variante sichtbar geprüft werden können.'
        : 'Kurze Rückmeldung für den aktuellen Zustand.';

    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: Scaffold(
        appBar: AppBar(title: const Text('Snackbar-Vorschau')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Direkte Vorschau des Snackbar-Inhalts und Trigger für alle fünf Zustände.',
            ),
            const SizedBox(height: 16),
            for (final type in AppSnackbarType.values) ...[
              Text(type.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              AppSnackbarContent(
                title: _titleForType(type),
                message: message,
                type: type,
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (innerContext) => Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () {
                      AppSnackbar.show(
                        innerContext,
                        title: _titleForType(type),
                        message: message,
                        type: type,
                        replaceCurrent: true,
                      );
                    },
                    child: Text('Als ${type.name} anzeigen'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  },
);

String _titleForType(AppSnackbarType type) {
  return switch (type) {
    AppSnackbarType.success => 'Erfolg',
    AppSnackbarType.warning => 'Hinweis',
    AppSnackbarType.error => 'Fehler',
    AppSnackbarType.info => 'Info',
    AppSnackbarType.help => 'Hilfe',
  };
}
