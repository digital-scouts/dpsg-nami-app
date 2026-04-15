import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';

void main() {
  Future<BuildContext> pumpManualHarness(
    WidgetTester tester, {
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) async {
    late BuildContext builtContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        scaffoldMessengerKey: messengerKey,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              builtContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return builtContext;
  }

  Widget buildHarness({
    required AppSnackbarType type,
    required String message,
    String? title,
  }) {
    return MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppSnackbar.show(
                context,
                message: message,
                title: title,
                type: type,
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('zeigt Standardtitel und Icon fuer Success', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        type: AppSnackbarType.success,
        message: 'Person erfolgreich aktualisiert.',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Erfolg'), findsOneWidget);
    expect(find.text('Person erfolgreich aktualisiert.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('nutzt expliziten Titel fuer Help', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        type: AppSnackbarType.help,
        title: 'Bearbeitungshilfe',
        message: 'Bitte pruefe die Eingaben noch einmal.',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bearbeitungshilfe'), findsOneWidget);
    expect(find.text('Bitte pruefe die Eingaben noch einmal.'), findsOneWidget);
    expect(find.byIcon(Icons.help_rounded), findsOneWidget);
  });

  testWidgets('zeigt Standardtitel und Icon fuer Warning, Error und Info', (
    tester,
  ) async {
    final context = await pumpManualHarness(tester);

    AppSnackbar.show(
      context,
      message: 'Warnung sichtbar',
      type: AppSnackbarType.warning,
    );
    await tester.pumpAndSettle();

    expect(find.text('Hinweis'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    AppSnackbar.show(
      context,
      message: 'Fehler sichtbar',
      type: AppSnackbarType.error,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Fehler'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(find.text('Warnung sichtbar'), findsNothing);

    AppSnackbar.show(
      context,
      message: 'Info sichtbar',
      type: AppSnackbarType.info,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Info'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(find.text('Fehler sichtbar'), findsNothing);
  });

  testWidgets('showOnMessenger nutzt globalen ScaffoldMessenger', (
    tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    final context = await pumpManualHarness(tester, messengerKey: messengerKey);

    AppSnackbar.showOnMessenger(
      messenger: messengerKey.currentState,
      context: context,
      message: 'Globaler Snackbar-Test',
      type: AppSnackbarType.success,
    );
    await tester.pumpAndSettle();

    expect(find.text('Erfolg'), findsOneWidget);
    expect(find.text('Globaler Snackbar-Test'), findsOneWidget);
  });

  testWidgets('lange Nachrichten werden im Content begrenzt dargestellt', (
    tester,
  ) async {
    const message =
        'Dies ist eine sehr lange Nachricht, die über mehrere Zeilen laufen soll, damit die maximale Zeilenanzahl im neuen Snackbar-Content stabil geprüft werden kann.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSnackbarContent(
            title: 'Info',
            message: message,
            type: AppSnackbarType.info,
          ),
        ),
      ),
    );

    final messageText = tester.widget<Text>(find.text(message));
    expect(messageText.maxLines, 4);
  });
}
