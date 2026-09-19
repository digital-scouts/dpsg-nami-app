import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';

/// Renders one chat bubble. Shared between the live chat (nami_ai_chat_page.dart) and the
/// read-only history detail view (nami_ai_chat_history_detail_page.dart, specs/nami-ai-
/// roadmap.md section 3.7) so both stay visually identical without duplicating the
/// bubble/markdown/source-line logic.
class NamiAiMessageBubble extends StatelessWidget {
  const NamiAiMessageBubble({
    super.key,
    required this.message,
    this.onSourceTap,
    this.onFeedback,
  });

  final NamiAiChatMessage message;

  /// Tapped a source chip - the bubble stays presentation-only, the caller resolves the source
  /// to its paragraph text (specs/nami-ai-roadmap.md section 3.12) and decides how to show it.
  final void Function(NamiAiSourceRef source)? onSourceTap;

  /// Tapped a thumbs up/down button ('up'/'down') - null in the read-only history detail view
  /// (no debugRequestId there, see NamiAiChatMessage), which is how that view hides the buttons.
  final void Function(String rating)? onFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final showUnclearHint = !isUser && message.unclear;
    final background = isUser
        ? theme.colorScheme.primaryContainer
        : showUnclearHint
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: showUnclearHint
              ? Border.all(color: theme.colorScheme.outlineVariant)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Text(message.text)
            else
              MarkdownBody(
                // Empty during the very first streaming instant, before the first partial
                // chunk arrived - an ellipsis reads better than a blank bubble.
                data: message.text.isEmpty ? '…' : message.text,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  theme,
                ).copyWith(p: theme.textTheme.bodyMedium),
              ),
            if (showUnclearHint)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nicht eindeutig belegt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && message.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: message.sources
                      .map(
                        (source) => ActionChip(
                          label: Text(
                            '${source.docTitle} § ${source.sectionNumber}',
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onPressed: onSourceTap == null
                              ? null
                              : () => onSourceTap!(source),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            if (onFeedback != null && !isUser && message.debugRequestId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Antwort war hilfreich',
                      icon: Icon(
                        message.feedback == 'up'
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                      ),
                      onPressed: () => onFeedback!('up'),
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Antwort war nicht hilfreich',
                      icon: Icon(
                        message.feedback == 'down'
                            ? Icons.thumb_down
                            : Icons.thumb_down_outlined,
                      ),
                      onPressed: () => onFeedback!('down'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
