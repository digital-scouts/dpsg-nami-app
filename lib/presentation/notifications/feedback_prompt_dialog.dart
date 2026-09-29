import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:wiredash/wiredash.dart';

import '../../domain/achievements/achievement_definition.dart';
import '../../l10n/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../services/feedback_prompt_service.dart';
import '../../services/logger_service.dart';

const String appStoreId = '6468066816';

enum FeedbackPromptChoice { feedback, rate, later }

/// Zeigt den Feedback-Dialog, fuehrt die gewaehlte Aktion aus und trackt sie.
///
/// Ohne [service] (z. B. aus den Debug-Tools) wird kein Anzeige-Status
/// gespeichert. Mit [achievements] zählen Feedback und Bewertung als Erfolg;
/// ob wirklich abgeschickt wurde, ist technisch nicht erkennbar.
Future<void> runFeedbackPromptFlow(
  BuildContext context, {
  required LoggerService logger,
  required String trigger,
  FeedbackPromptService? service,
  AchievementService? achievements,
}) async {
  await service?.markShown();
  await logger.trackAndLog('feedback', 'feedback_prompt', {
    'action': 'shown',
    'trigger': trigger,
  });
  if (!context.mounted) return;

  final choice = await showFeedbackPromptDialog(context);
  await logger.trackAndLog('feedback', 'feedback_prompt', {
    'action': choice.name,
    'trigger': trigger,
  });

  switch (choice) {
    case FeedbackPromptChoice.later:
      await service?.markSnoozed();
    case FeedbackPromptChoice.feedback:
      await service?.markCompleted();
      unawaited(achievements?.record(AchievementIds.feedbackSent));
      if (context.mounted) {
        await Wiredash.of(context).show(inheritMaterialTheme: true);
      }
    case FeedbackPromptChoice.rate:
      await service?.markCompleted();
      unawaited(achievements?.record(AchievementIds.storeRating));
      try {
        await InAppReview.instance.openStoreListing(appStoreId: appStoreId);
      } catch (error) {
        await logger.log('feedback', 'Store-Link fehlgeschlagen: $error');
      }
  }
}

Future<FeedbackPromptChoice> showFeedbackPromptDialog(
  BuildContext context,
) async {
  final choice = await showDialog<FeedbackPromptChoice>(
    context: context,
    builder: (ctx) => const FeedbackPromptDialog(),
  );
  return choice ?? FeedbackPromptChoice.later;
}

class FeedbackPromptDialog extends StatelessWidget {
  const FeedbackPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void close(FeedbackPromptChoice choice) =>
        Navigator.of(context).pop(choice);

    return AlertDialog(
      title: Text(t.t('feedback_prompt_title')),
      content: Text(t.t('feedback_prompt_body')),
      actions: [
        TextButton(
          onPressed: () => close(FeedbackPromptChoice.later),
          child: Text(t.t('feedback_prompt_later')),
        ),
        TextButton(
          onPressed: () => close(FeedbackPromptChoice.feedback),
          child: Text(t.t('feedback_prompt_feedback')),
        ),
        FilledButton(
          onPressed: () => close(FeedbackPromptChoice.rate),
          child: Text(t.t('feedback_prompt_rate')),
        ),
      ],
    );
  }
}
