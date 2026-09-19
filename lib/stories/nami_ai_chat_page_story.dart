import 'package:flutter/material.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_detail_page.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_list_page.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_page.dart';
import 'package:nami/services/nami_ai/nami_ai_debug_log_service.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';
import 'package:nami/services/nami_ai/nami_ai_stream_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story namiAiChatPageEmptyStory() =>
    Story(name: 'NaMi AI/Chat/Leer', builder: (context) => _chatShell());

Story namiAiChatPageWithSourcesStory() => Story(
  name: 'NaMi AI/Chat/Antwort mit Quellen',
  builder: (context) => _chatShell(
    initialMessages: const [
      NamiAiChatMessage(
        text: 'Wie oft muss die Stammesversammlung stattfinden?',
        isUser: true,
      ),
      NamiAiChatMessage(
        text:
            'Die Stammesversammlung tritt **mindestens einmal jährlich** zusammen.',
        isUser: false,
        sources: [
          NamiAiSourceRef(
            docTitle: 'Satzung Stamm',
            sectionNumber: '18',
            docStand: 'Mai 2024',
          ),
        ],
      ),
    ],
  ),
);

Story namiAiChatPageUnclearStory() => Story(
  name: 'NaMi AI/Chat/Nicht eindeutig belegt',
  builder: (context) => _chatShell(
    initialMessages: const [
      NamiAiChatMessage(
        text: 'Wie viele Urlaubstage hat ein Vorstand?',
        isUser: true,
      ),
      NamiAiChatMessage(
        text: 'Dazu liegt mir keine Quelle vor.',
        isUser: false,
        unclear: true,
      ),
    ],
  ),
);

Story namiAiChatPageStreamingStory() => Story(
  name: 'NaMi AI/Chat/Streaming laeuft',
  builder: (context) => _chatShell(
    initialMessages: const [
      NamiAiChatMessage(
        text: 'Wie werden Anträge in der Stammesversammlung gestellt?',
        isUser: true,
      ),
      NamiAiChatMessage(text: 'Anträge müssen', isUser: false),
    ],
  ),
);

Story namiAiChatPageErrorStory() => Story(
  name: 'NaMi AI/Chat/Fehler',
  builder: (context) => _chatShell(
    initialMessages: const [
      NamiAiChatMessage(text: 'Wie oft tagt die SV?', isUser: true),
      NamiAiChatMessage(
        text: 'Fehler: Die AI-Antwort konnte nicht geladen werden.',
        isUser: false,
      ),
    ],
  ),
);

Story namiAiChatHistoryListEmptyStory() => Story(
  name: 'NaMi AI/Verlauf/Leer',
  builder: (context) => MultiProvider(
    providers: [
      Provider<NamiAiChatHistoryRepository>.value(
        value: _StoryNamiAiChatHistoryRepository(const []),
      ),
    ],
    child: const MaterialApp(home: NamiAiChatHistoryListPage()),
  ),
);

Story namiAiChatHistoryListFilledStory() => Story(
  name: 'NaMi AI/Verlauf/Gefuellt',
  builder: (context) => MultiProvider(
    providers: [
      Provider<NamiAiChatHistoryRepository>.value(
        value: _StoryNamiAiChatHistoryRepository([
          NamiAiChatHistoryEntry(
            id: '1',
            startedAt: DateTime(2026, 9, 1, 10, 30),
            title: 'Wie oft muss die Stammesversammlung stattfinden?',
            messages: const [],
          ),
          NamiAiChatHistoryEntry(
            id: '2',
            startedAt: DateTime(2026, 8, 20, 15, 5),
            title: 'Wer darf an der Stammesversammlung teilnehmen?',
            messages: const [],
          ),
        ]),
      ),
    ],
    child: const MaterialApp(home: NamiAiChatHistoryListPage()),
  ),
);

Story namiAiChatHistoryDetailStory() => Story(
  name: 'NaMi AI/Verlauf/Detail',
  builder: (context) => MaterialApp(
    home: NamiAiChatHistoryDetailPage(
      entry: NamiAiChatHistoryEntry(
        id: '1',
        startedAt: DateTime(2026, 9, 1, 10, 30),
        title: 'Wie oft muss die Stammesversammlung stattfinden?',
        messages: const [
          NamiAiChatMessage(
            text: 'Wie oft muss die Stammesversammlung stattfinden?',
            isUser: true,
          ),
          NamiAiChatMessage(
            text:
                'Die Stammesversammlung tritt mindestens einmal jährlich zusammen.',
            isUser: false,
            sources: [
              NamiAiSourceRef(
                docTitle: 'Satzung Stamm',
                sectionNumber: '18',
                docStand: 'Mai 2024',
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

Widget _chatShell({List<NamiAiChatMessage>? initialMessages}) {
  return MultiProvider(
    providers: [
      Provider<NamiAiService>.value(value: _StoryNamiAiService()),
      Provider<NamiAiStreamService>.value(value: _StoryNamiAiStreamService()),
      Provider<NamiAiDebugLogService>.value(value: _StoryDebugLogService()),
      Provider<NamiAiChatHistoryRepository>.value(
        value: _StoryNamiAiChatHistoryRepository(const []),
      ),
    ],
    child: MaterialApp(
      home: NamiAiChatPage(debugInitialMessages: initialMessages),
    ),
  );
}

class _StoryNamiAiService extends NamiAiService {
  @override
  Future<String> startSession() async => 'story-session';

  @override
  Future<void> endSession(String sessionId) async {}
}

/// Never actually invoked by the stories above (they seed the transcript directly via
/// debugInitialMessages instead of scripting a send), but NamiAiChatPage still reads this
/// Provider eagerly - a canned "done" stream keeps it harmless if a viewer does type and send.
class _StoryNamiAiStreamService extends NamiAiStreamService {
  @override
  Stream<NamiAiStreamChunk> respond({
    required String sessionId,
    required String prompt,
  }) async* {
    yield NamiAiStreamChunk.done(
      const NamiAiReply(answer: 'Story-Antwort.', contextChunks: []),
    );
  }
}

class _StoryDebugLogService extends NamiAiDebugLogService {
  @override
  Future<void> logEntry({
    required String prompt,
    required bool success,
    String? answer,
    List<String> contextChunks = const <String>[],
    String? errorCode,
    String? errorMessage,
    required int latencyMs,
  }) async {}
}

class _StoryNamiAiChatHistoryRepository implements NamiAiChatHistoryRepository {
  _StoryNamiAiChatHistoryRepository(this._entries);

  final List<NamiAiChatHistoryEntry> _entries;

  @override
  Future<List<NamiAiChatHistoryEntry>> loadAll() async => _entries;

  @override
  Future<void> save(NamiAiChatHistoryEntry entry) async {}
}
