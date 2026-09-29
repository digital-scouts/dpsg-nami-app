import 'nami_ai_chat_history_entry.dart';

abstract class NamiAiChatHistoryRepository {
  /// Returns all non-expired entries, newest first. Implementations drop entries older than
  /// NamiAiChatHistoryEntry.retention as a side effect of loading (specs/nami-ai-roadmap.md
  /// section 3.7) - there is no background job, cleanup happens opportunistically on read.
  Future<List<NamiAiChatHistoryEntry>> loadAll();

  /// Persists (or overwrites, if entry.id already exists) one conversation. Deliberately no
  /// delete(id): per the product decision behind section 3.7's persistence design, a saved
  /// conversation is read-only and expires automatically - users never delete manually.
  Future<void> save(NamiAiChatHistoryEntry entry);
}
