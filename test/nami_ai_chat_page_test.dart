import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_page.dart';
import 'package:nami/services/nami_ai/nami_ai_corpus_lookup_service.dart';
import 'package:nami/services/nami_ai/nami_ai_debug_log_service.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';
import 'package:nami/services/nami_ai/nami_ai_stream_service.dart';
import 'package:provider/provider.dart';

/// Avoids real file I/O (and the platform call inside PackageInfo.fromPlatform) in widget
/// tests - NamiAiDebugLogService is a plain concrete class with no interface, so overriding
/// logEntry() is the straightforward way to stub it out.
class _NoOpDebugLogService extends NamiAiDebugLogService {
  @override
  Future<String> logEntry({
    required String prompt,
    required bool success,
    String? answer,
    List<String> contextChunks = const <String>[],
    List<Map<String, String>> sources = const <Map<String, String>>[],
    bool unclear = false,
    String? sessionId,
    int? turnIndex,
    bool contextTruncated = false,
    String? errorCode,
    String? errorMessage,
    required int latencyMs,
  }) async => 'no-op-request-id';

  @override
  Future<void> updateFeedback({
    required String requestId,
    required String rating,
  }) async {}

  @override
  Future<void> deleteAll() async {}
}

/// Records updateFeedback()/deleteAll() calls so a test can assert the chat page called them
/// correctly, without touching the real file-backed implementation.
class _SpyDebugLogService extends _NoOpDebugLogService {
  final List<({String requestId, String rating})> feedbackCalls = [];
  int deleteAllCallCount = 0;

  @override
  Future<void> updateFeedback({
    required String requestId,
    required String rating,
  }) async {
    feedbackCalls.add((requestId: requestId, rating: rating));
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCallCount += 1;
  }
}

/// Returns a canned `Stream<NamiAiStreamChunk>` instead of going through the real
/// com.namiapp/nami_ai_stream EventChannel. Deliberately NOT mocked via
/// TestDefaultBinaryMessengerBinding.setMockStreamHandler: EventChannel.receiveBroadcastStream()
/// consumed via `await for` inside a testWidgets body never settles under
/// AutomatedTestWidgetsFlutterBinding's FakeAsync test zone (reproduced with a minimal repro
/// containing zero application code - a real cross-package/SDK-level incompatibility, not a bug
/// in NamiAiStreamService). A plain in-memory stream sidesteps the platform channel entirely and
/// settles normally.
class _FakeNamiAiStreamService extends NamiAiStreamService {
  _FakeNamiAiStreamService(this._streamBuilder);

  final Stream<NamiAiStreamChunk> Function({
    required String sessionId,
    required String prompt,
  })
  _streamBuilder;

  @override
  Stream<NamiAiStreamChunk> respond({
    required String sessionId,
    required String prompt,
  }) => _streamBuilder(sessionId: sessionId, prompt: prompt);
}

class _FakeNamiAiChatHistoryRepository implements NamiAiChatHistoryRepository {
  final List<NamiAiChatHistoryEntry> saved = <NamiAiChatHistoryEntry>[];

  @override
  Future<List<NamiAiChatHistoryEntry>> loadAll() async =>
      List<NamiAiChatHistoryEntry>.from(saved);

  @override
  Future<void> save(NamiAiChatHistoryEntry entry) async {
    saved.removeWhere((existing) => existing.id == entry.id);
    saved.add(entry);
  }
}

Stream<NamiAiStreamChunk> _doneOnlyStream(NamiAiReply reply) async* {
  yield NamiAiStreamChunk.done(reply);
}

Stream<NamiAiStreamChunk> _partialsThenDoneStream({
  required List<String> partials,
  required NamiAiReply reply,
}) async* {
  for (final partial in partials) {
    yield NamiAiStreamChunk.partial(partial);
  }
  yield NamiAiStreamChunk.done(reply);
}

Stream<NamiAiStreamChunk> _errorStream(Object error) async* {
  throw error;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methodChannel = MethodChannel('com.namiapp/nami_ai');
  final binaryMessenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late _FakeNamiAiChatHistoryRepository historyRepository;

  setUp(() {
    historyRepository = _FakeNamiAiChatHistoryRepository();
    binaryMessenger.setMockMethodCallHandler(methodChannel, (call) async {
      switch (call.method) {
        case 'startChatSession':
          return {'sessionId': 'session-1'};
        case 'endChatSession':
          return null;
        default:
          throw PlatformException(
            code: 'unimplemented',
            message: 'Unerwarteter Methodenaufruf: ${call.method}',
          );
      }
    });
  });

  tearDown(() {
    binaryMessenger.setMockMethodCallHandler(methodChannel, null);
  });

  Future<void> pumpChatPage(
    WidgetTester tester, {
    required Stream<NamiAiStreamChunk> Function({
      required String sessionId,
      required String prompt,
    })
    streamBuilder,
    NamiAiDebugLogService? debugLogService,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<NamiAiService>.value(value: NamiAiService()),
          Provider<NamiAiStreamService>.value(
            value: _FakeNamiAiStreamService(streamBuilder),
          ),
          Provider<NamiAiDebugLogService>.value(
            value: debugLogService ?? _NoOpDebugLogService(),
          ),
          Provider<NamiAiCorpusLookupService>.value(
            value: NamiAiCorpusLookupService(),
          ),
          Provider<NamiAiChatHistoryRepository>.value(value: historyRepository),
        ],
        child: MaterialApp(
          // AppSnackbar.show() (used by "Logs löschen"/share failures) reads
          // AppLocalizations.of(context) - needs the delegate registered even though this test
          // suite otherwise doesn't care about localization.
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: const [Locale('de'), Locale('en')],
          home: const NamiAiChatPage(),
        ),
      ),
    );
    await tester.pump();
  }

  // A handful of small pumps rather than pumpAndSettle(): a focused TextField's cursor blink is
  // a periodic timer that reschedules a frame forever, so pumpAndSettle() never considers the
  // tree "settled". This is enough to drain the fake stream and let the 180ms scroll animation
  // finish.
  Future<void> pumpBriefly(WidgetTester tester, {int times = 6}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'zeigt Hinweistext, solange noch keine Nachricht gesendet wurde',
    (tester) async {
      await pumpChatPage(
        tester,
        streamBuilder: ({required sessionId, required prompt}) =>
            _doneOnlyStream(
              const NamiAiReply(answer: 'egal', contextChunks: []),
            ),
      );

      expect(find.textContaining('Teste den Chat'), findsOneWidget);
    },
  );

  testWidgets(
    'aktualisiert die letzte Bubble mit wachsenden Streaming-Partials',
    (tester) async {
      await pumpChatPage(
        tester,
        streamBuilder: ({required sessionId, required prompt}) =>
            _partialsThenDoneStream(
              partials: const ['Mind', 'Mindestens einmal'],
              reply: const NamiAiReply(
                answer: 'Mindestens einmal jaehrlich.',
                contextChunks: [],
              ),
            ),
      );

      await tester.enterText(find.byType(TextField), 'Wie oft tagt die SV?');
      await tester.tap(find.byIcon(Icons.send));
      await pumpBriefly(tester);

      expect(find.text('Mindestens einmal jaehrlich.'), findsOneWidget);
    },
  );

  testWidgets('zeigt Quellen als §-Referenzen bei der fertigen Antwort', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      streamBuilder: ({required sessionId, required prompt}) => _doneOnlyStream(
        const NamiAiReply(
          answer: 'Mindestens einmal jaehrlich.',
          contextChunks: [],
          sources: [
            NamiAiSourceRef(
              docTitle: 'Satzung Stamm',
              sectionNumber: '18',
              docStand: 'Mai 2024',
            ),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Wie oft tagt die SV?');
    await tester.tap(find.byIcon(Icons.send));
    await pumpBriefly(tester);

    expect(find.textContaining('Satzung Stamm § 18'), findsOneWidget);
  });

  testWidgets(
    'Daumen-hoch-Tap markiert die Bubble und ruft updateFeedback auf',
    (tester) async {
      final logService = _SpyDebugLogService();
      await pumpChatPage(
        tester,
        debugLogService: logService,
        streamBuilder: ({required sessionId, required prompt}) =>
            _doneOnlyStream(
              const NamiAiReply(
                answer: 'Mindestens einmal jaehrlich.',
                contextChunks: [],
              ),
            ),
      );

      await tester.enterText(find.byType(TextField), 'Wie oft tagt die SV?');
      await tester.tap(find.byIcon(Icons.send));
      await pumpBriefly(tester);

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      expect(logService.feedbackCalls, [
        (requestId: 'no-op-request-id', rating: 'up'),
      ]);

      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pump();

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(logService.feedbackCalls.length, 2);
      expect(logService.feedbackCalls.last.rating, 'up');
    },
  );

  testWidgets(
    '"Logs löschen" im Menü ruft deleteAll auf und zeigt eine Bestaetigung',
    (tester) async {
      final logService = _SpyDebugLogService();
      await pumpChatPage(
        tester,
        debugLogService: logService,
        streamBuilder: ({required sessionId, required prompt}) =>
            _doneOnlyStream(
              const NamiAiReply(answer: 'egal', contextChunks: []),
            ),
      );

      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logs löschen'));
      await tester.pumpAndSettle();

      expect(logService.deleteAllCallCount, 1);
      expect(find.text('Debug-Log gelöscht.'), findsOneWidget);
    },
  );

  testWidgets('zeigt einen Hinweis, wenn die Antwort unclear ist', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      streamBuilder: ({required sessionId, required prompt}) => _doneOnlyStream(
        const NamiAiReply(
          answer: 'Dazu liegt mir keine Quelle vor.',
          contextChunks: [],
          unclear: true,
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Was ist der Sinn des Lebens?',
    );
    await tester.tap(find.byIcon(Icons.send));
    await pumpBriefly(tester);

    expect(find.text('Nicht eindeutig belegt'), findsOneWidget);
  });

  testWidgets('rendert Markdown-Antworten statt Rohsternchen anzuzeigen', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      streamBuilder: ({required sessionId, required prompt}) => _doneOnlyStream(
        const NamiAiReply(answer: 'Das ist **wichtig**.', contextChunks: []),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Frage');
    await tester.tap(find.byIcon(Icons.send));
    await pumpBriefly(tester);

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('wichtig'), findsOneWidget);
  });

  testWidgets('zeigt eine Fehler-Bubble, wenn das Streaming fehlschlaegt', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      streamBuilder: ({required sessionId, required prompt}) => _errorStream(
        NamiAiException(code: 'ai_generation_failed', message: 'Boom'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Frage');
    await tester.tap(find.byIcon(Icons.send));
    await pumpBriefly(tester);

    expect(find.textContaining('Fehler'), findsOneWidget);
  });

  testWidgets('zeigt die feste Ablehnungsantwort bei Schreibverben unveraendert an', (
    tester,
  ) async {
    // Der Schreibverben-Vorfilter selbst laeuft nativ (NamiAiWriteIntentFilter, siehe
    // NamiAiWriteIntentFilterTests.swift) und liefert diesen festen Text als ganz normales
    // done-Event ohne Partials - aus Dart-Sicht ist das nicht von jeder anderen Antwort zu
    // unterscheiden. Dieser Test sichert nur ab, dass die UI diesen Text unveraendert anzeigt.
    const rejectionText =
        'Ich kann aktuell keine Änderungen in NaMi vornehmen, sondern nur Fragen '
        'beantworten. Bitte nutze dafür die passende Stelle in der App.';
    await pumpChatPage(
      tester,
      streamBuilder: ({required sessionId, required prompt}) => _doneOnlyStream(
        const NamiAiReply(answer: rejectionText, contextChunks: []),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Lösche den Eintrag von Max Mustermann',
    );
    await tester.tap(find.byIcon(Icons.send));
    await pumpBriefly(tester);

    expect(find.text(rejectionText), findsOneWidget);
  });
}
