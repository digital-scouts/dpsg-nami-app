import 'package:flutter/material.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/services/nami_ai/nami_ai_corpus_lookup_service.dart';

/// Shared "tap a source chip -> show its paragraph" sheet (specs/nami-ai-roadmap.md section
/// 3.12), used from both the live chat and the read-only history detail view so the two stay
/// visually identical (same pattern as NamiAiMessageBubble itself being shared between them).
Future<void> showNamiAiSourceSheet(
  BuildContext context,
  NamiAiCorpusLookupService lookupService,
  NamiAiSourceRef source,
) async {
  final chunk = await lookupService.lookup(
    source.docTitle,
    source.sectionNumber,
  );
  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${source.docTitle} § ${source.sectionNumber}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Stand ${source.docStand}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      chunk?.text ??
                          'Dieser Abschnitt konnte nicht gefunden werden.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
