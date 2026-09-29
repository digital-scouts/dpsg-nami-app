import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/feedback_prompt_dialog.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story feedbackPromptDialogStory() => Story(
  name: 'App/Feedback/Feedback-Dialog',
  builder: (context) {
    final locale = context.knobs.options<Locale>(
      label: 'Sprache',
      initial: const Locale('de'),
      options: const [
        Option(label: 'Deutsch', value: Locale('de')),
        Option(label: 'Englisch', value: Locale('en')),
      ],
    );

    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: locale,
      home: const Scaffold(body: Center(child: FeedbackPromptDialog())),
    );
  },
);
