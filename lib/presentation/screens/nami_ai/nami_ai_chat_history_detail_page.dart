import 'package:flutter/material.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/presentation/screens/nami_ai/widgets/nami_ai_message_bubble.dart';

/// Read-only transcript of one past conversation (specs/nami-ai-roadmap.md section 3.7): no
/// input field, no send button, no way to continue it - a saved conversation is for re-reading
/// only, since the native LanguageModelSession it belonged to is long gone.
class NamiAiChatHistoryDetailPage extends StatelessWidget {
  const NamiAiChatHistoryDetailPage({super.key, required this.entry});

  final NamiAiChatHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: entry.messages.length,
          itemBuilder: (context, index) =>
              NamiAiMessageBubble(message: entry.messages[index]),
        ),
      ),
    );
  }
}
