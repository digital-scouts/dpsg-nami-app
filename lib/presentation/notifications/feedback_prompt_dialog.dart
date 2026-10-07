import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wiredash/wiredash.dart';

import '../../domain/achievements/achievement_definition.dart';
import '../../l10n/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../services/feedback_prompt_service.dart';
import '../../services/logger_service.dart';
import '../../services/store_review_client.dart';

enum FeedbackPromptChoice { feedback, rate, later }

/// Zeigt den Feedback-Dialog, fuehrt die gewaehlte Aktion aus und trackt sie.
///
/// Ohne [service] (z. B. aus den Debug-Tools) wird kein Anzeige-Status
/// gespeichert. Mit [achievements] zählt Feedback als Erfolg; ob wirklich
/// abgeschickt wurde, ist technisch nicht erkennbar. Eine Bewertung zählt
/// hier nie als Erfolg, weil Google Anreize fuer Bewertungen verbietet.
Future<void> runFeedbackPromptFlow(
  BuildContext context, {
  required LoggerService logger,
  required String trigger,
  FeedbackPromptService? service,
  AchievementService? achievements,
  StoreReviewClient? reviewClient,
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
      if (context.mounted) {
        await openFeedback(context, achievements: achievements);
      }
    case FeedbackPromptChoice.rate:
      await service?.markCompleted();
      await _requestPlayReview(
        reviewClient ?? InAppReviewStoreReviewClient(),
        logger,
      );
  }
}

/// Oeffnet das Wiredash-Feedback und zaehlt den Erfolg "Mitgestalten".
Future<void> openFeedback(
  BuildContext context, {
  AchievementService? achievements,
}) async {
  unawaited(achievements?.record(AchievementIds.feedbackSent));
  await Wiredash.of(context).show(inheritMaterialTheme: true);
}

/// Nur iOS: oeffnet als passiver Link die Bewertungsseite im App Store und
/// zaehlt danach den Erfolg "App bewertet".
Future<void> openAppStoreReviewPage({
  required LoggerService logger,
  AchievementService? achievements,
  StoreReviewClient? reviewClient,
}) async {
  try {
    await (reviewClient ?? InAppReviewStoreReviewClient()).openStoreListing();
    unawaited(achievements?.record(AchievementIds.storeRating));
  } catch (error) {
    await logger.log('feedback', 'Store-Link fehlgeschlagen: $error');
  }
}

/// Android: Google-Play-In-App-Review, sonst Rueckfall auf den Store-Eintrag.
Future<void> _requestPlayReview(
  StoreReviewClient client,
  LoggerService logger,
) async {
  try {
    if (await client.isAvailable()) {
      await client.requestReview();
    } else {
      await client.openStoreListing();
    }
  } catch (error) {
    await logger.log('feedback', 'Store-Bewertung fehlgeschlagen: $error');
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
  const FeedbackPromptDialog({super.key, this.platform});

  /// Ohne Angabe gilt [defaultTargetPlatform]; Storybook setzt sie fest.
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void close(FeedbackPromptChoice choice) =>
        Navigator.of(context).pop(choice);

    // Nur Android bietet hier "App bewerten" an. Apple erlaubt aktive
    // Bewertungsaufforderungen nur ueber den Systemdialog.
    final offersRating =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    if (!offersRating) {
      return AlertDialog(
        title: Text(t.t('feedback_prompt_title')),
        content: Text(t.t('feedback_prompt_body_ios')),
        actions: [
          TextButton(
            onPressed: () => close(FeedbackPromptChoice.later),
            child: Text(t.t('feedback_prompt_later')),
          ),
          FilledButton(
            onPressed: () => close(FeedbackPromptChoice.feedback),
            child: Text(t.t('feedback_prompt_feedback')),
          ),
        ],
      );
    }

    // Android: Knoepfe gestapelt in voller Breite, "App bewerten" zuerst.
    return AlertDialog(
      title: Text(t.t('feedback_prompt_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.t('feedback_prompt_body_android')),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('feedback-prompt-rate'),
            onPressed: () => close(FeedbackPromptChoice.rate),
            icon: const Icon(Icons.star_rounded),
            label: Text(t.t('feedback_prompt_rate')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('feedback-prompt-feedback'),
            onPressed: () => close(FeedbackPromptChoice.feedback),
            icon: const Icon(Icons.forum_outlined),
            label: Text(t.t('feedback_prompt_feedback')),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('feedback-prompt-later'),
            onPressed: () => close(FeedbackPromptChoice.later),
            child: Text(t.t('feedback_prompt_later')),
          ),
        ],
      ),
    );
  }
}
