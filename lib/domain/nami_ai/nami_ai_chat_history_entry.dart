/// Plain Dart mirror of NamiAiKit's NamiAiSourceRef (ios/NamiAiKit/Sources/NamiAiKit/
/// NamiAiSourceRef.swift) - a grounding-gate-verified citation, never a raw model claim.
class NamiAiSourceRef {
  const NamiAiSourceRef({
    required this.docTitle,
    required this.sectionNumber,
    required this.docStand,
  });

  final String docTitle;
  final String sectionNumber;
  final String docStand;
}

/// One chat bubble, either the user's question or the assistant's (already grounding-gate
/// verified, see specs/nami-ai-roadmap.md section 3.6/3.7) reply.
class NamiAiChatMessage {
  const NamiAiChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const <NamiAiSourceRef>[],
    this.unclear = false,
  });

  final String text;
  final bool isUser;
  final List<NamiAiSourceRef> sources;
  final bool unclear;
}

/// One past conversation, persisted read-only for 30 days (specs/nami-ai-roadmap.md section
/// 3.7: history is for re-reading only, a saved entry can never be reopened/continued - a new
/// conversation always starts a fresh native session). title is the first user question;
/// startedAt is that first message's timestamp, shown as the list entry's subtitle.
class NamiAiChatHistoryEntry {
  const NamiAiChatHistoryEntry({
    required this.id,
    required this.startedAt,
    required this.title,
    required this.messages,
  });

  static const Duration retention = Duration(days: 30);

  final String id;
  final DateTime startedAt;
  final String title;
  final List<NamiAiChatMessage> messages;

  bool isExpired(DateTime now) => now.difference(startedAt) > retention;
}
